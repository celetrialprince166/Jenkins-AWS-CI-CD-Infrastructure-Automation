#!/bin/bash
# ============================================================================
# CONTROLLER USER DATA SCRIPT
# ============================================================================
# PURPOSE: Configure controller instance at launch (mount EFS, setup SSH keys)
# LOCATION: terraform/templates/controller-user-data.sh
# VARIABLES: Populated by Terraform templatefile()
# ============================================================================

set -e

# Log everything
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Starting controller user data script ==="
echo "Timestamp: $(date)"

# Variables from Terraform
EFS_DNS="${efs_dns_name}"
JENKINS_HOME="${jenkins_home}"
JENKINS_USER="${jenkins_user}"
AWS_REGION="${aws_region}"
AGENT_SSH_KEY_SECRET="${agent_ssh_key_secret_name}"

echo "EFS DNS: $EFS_DNS"
echo "Jenkins Home: $JENKINS_HOME"
echo "Jenkins User: $JENKINS_USER"
echo "AWS Region: $AWS_REGION"

# --------------------------------------------------------------------------
# STEP 1: Install required packages
# --------------------------------------------------------------------------
echo "=== Installing required packages ==="
apt-get update
apt-get install -y nfs-common awscli jq

# --------------------------------------------------------------------------
# STEP 2: Wait for EFS to be available
# --------------------------------------------------------------------------
echo "=== Waiting for EFS mount target ==="
while ! nc -z $EFS_DNS 2049; do
  echo "Waiting for EFS mount target to be available..."
  sleep 10
done
echo "EFS mount target is available"

# --------------------------------------------------------------------------
# STEP 3: Stop Jenkins before mounting
# --------------------------------------------------------------------------
echo "=== Stopping Jenkins ==="
systemctl stop jenkins || true

# --------------------------------------------------------------------------
# STEP 4: Backup existing Jenkins home (if any)
# --------------------------------------------------------------------------
if [ -d "$JENKINS_HOME" ] && [ "$(ls -A $JENKINS_HOME 2>/dev/null)" ]; then
  echo "=== Backing up existing Jenkins home ==="
  mv $JENKINS_HOME $JENKINS_HOME.backup.$(date +%Y%m%d%H%M%S)
fi

# --------------------------------------------------------------------------
# STEP 5: Create mount point
# --------------------------------------------------------------------------
echo "=== Creating mount point ==="
mkdir -p $JENKINS_HOME

# --------------------------------------------------------------------------
# STEP 6: Mount EFS
# --------------------------------------------------------------------------
echo "=== Mounting EFS ==="
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $EFS_DNS:/ $JENKINS_HOME

# Verify mount
if mountpoint -q $JENKINS_HOME; then
  echo "EFS mounted successfully"
else
  echo "ERROR: EFS mount failed"
  exit 1
fi

# --------------------------------------------------------------------------
# STEP 7: Add to fstab for persistence
# --------------------------------------------------------------------------
echo "=== Adding to fstab ==="
# Remove any existing entry
sed -i "\|$JENKINS_HOME|d" /etc/fstab
# Add new entry
echo "$EFS_DNS:/ $JENKINS_HOME nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" >> /etc/fstab

# --------------------------------------------------------------------------
# STEP 8: Set ownership
# --------------------------------------------------------------------------
echo "=== Setting ownership ==="
chown -R $JENKINS_USER:$JENKINS_USER $JENKINS_HOME

# --------------------------------------------------------------------------
# STEP 9: Create Jenkins directories if they don't exist
# --------------------------------------------------------------------------
echo "=== Creating Jenkins directories ==="
for dir in jobs plugins secrets users nodes logs .ssh; do
  mkdir -p $JENKINS_HOME/$dir
  chown $JENKINS_USER:$JENKINS_USER $JENKINS_HOME/$dir
done

# --------------------------------------------------------------------------
# STEP 10: Retrieve SSH private key from Secrets Manager
# --------------------------------------------------------------------------
echo "=== Retrieving SSH private key for agent communication ==="
SSH_DIR="$JENKINS_HOME/.ssh"
PRIVATE_KEY_FILE="$SSH_DIR/jenkins_agent_key"

# Get the private key from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id "$AGENT_SSH_KEY_SECRET" \
  --region "$AWS_REGION" \
  --query 'SecretString' \
  --output text > "$PRIVATE_KEY_FILE"

# Set correct permissions (SSH requires strict permissions)
chmod 600 "$PRIVATE_KEY_FILE"
chown $JENKINS_USER:$JENKINS_USER "$PRIVATE_KEY_FILE"

# Create SSH config for jenkins user
cat > "$SSH_DIR/config" << 'SSHCONFIG'
# SSH client configuration for Jenkins controller
# Used when connecting to agents

Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  IdentityFile ~/.ssh/jenkins_agent_key
  ServerAliveInterval 60
  ServerAliveCountMax 3
SSHCONFIG

chmod 600 "$SSH_DIR/config"
chown $JENKINS_USER:$JENKINS_USER "$SSH_DIR/config"
chmod 700 "$SSH_DIR"
chown $JENKINS_USER:$JENKINS_USER "$SSH_DIR"

echo "SSH private key configured successfully"

# --------------------------------------------------------------------------
# STEP 11: Start Jenkins
# --------------------------------------------------------------------------
echo "=== Starting Jenkins ==="
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to be ready
echo "=== Waiting for Jenkins to start ==="
for i in {1..60}; do
  if curl -s -o /dev/null -w "%%{http_code}" http://localhost:8080/login | grep -q "200\|403"; then
    echo "Jenkins is ready"
    break
  fi
  echo "Waiting for Jenkins... ($i/60)"
  sleep 10
done

# --------------------------------------------------------------------------
# STEP 12: Display status
# --------------------------------------------------------------------------
echo "=== Controller setup complete ==="
echo "Jenkins Status: $(systemctl is-active jenkins)"
echo "EFS Mount: $(df -h $JENKINS_HOME | tail -1)"
echo "SSH Key: $(ls -la $PRIVATE_KEY_FILE)"
echo "Timestamp: $(date)"
