#!/bin/bash
# ============================================================================
# AGENT USER DATA SCRIPT
# ============================================================================
2# PURPOSE: Configure agent instance at launch (setup SSH for controller access)
# LOCATION: terraform/templates/agent-user-data.sh
# VARIABLES: Populated by Terraform templatefile()
# ============================================================================

set -e

# Log everything
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Starting agent user data script ==="
echo "Timestamp: $(date)"

# Variables from Terraform
JENKINS_USER="${jenkins_user}"
CONTROLLER_PUBLIC_KEY="${controller_public_key}"

echo "Jenkins User: $JENKINS_USER"

# --------------------------------------------------------------------------
# STEP 1: Ensure jenkins user exists
# --------------------------------------------------------------------------
echo "=== Ensuring jenkins user exists ==="
if ! id -u $JENKINS_USER &>/dev/null; then
  useradd -m -s /bin/bash $JENKINS_USER
  echo "Created jenkins user"
else
  echo "Jenkins user already exists"
fi

# --------------------------------------------------------------------------
# STEP 2: Get jenkins home directory
# --------------------------------------------------------------------------
JENKINS_HOME=$(getent passwd $JENKINS_USER | cut -d: -f6)
SSH_DIR="$JENKINS_HOME/.ssh"

# --------------------------------------------------------------------------
# STEP 3: Configure SSH directory
# --------------------------------------------------------------------------
echo "=== Configuring SSH directory ==="
mkdir -p $SSH_DIR
chmod 700 $SSH_DIR

# --------------------------------------------------------------------------
# STEP 4: Add controller's public key to authorized_keys
# --------------------------------------------------------------------------
# This is the KEY step - the controller's public key goes here
# so the controller can SSH into this agent using its private key
echo "=== Adding controller's public key to authorized_keys ==="

AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# Write the public key (from Terraform variable)
echo "$CONTROLLER_PUBLIC_KEY" > $AUTHORIZED_KEYS

# Set strict permissions (SSH requires this)
chmod 600 $AUTHORIZED_KEYS
chown $JENKINS_USER:$JENKINS_USER $AUTHORIZED_KEYS

echo "Controller public key added to authorized_keys"

# --------------------------------------------------------------------------
# STEP 5: Configure SSH client (for any outbound connections)
# --------------------------------------------------------------------------
cat > $SSH_DIR/config << 'SSHCONFIG'
# SSH client configuration for Jenkins agent
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  ServerAliveInterval 60
  ServerAliveCountMax 3
SSHCONFIG

chmod 600 $SSH_DIR/config
chown $JENKINS_USER:$JENKINS_USER $SSH_DIR/config

# Set ownership of entire .ssh directory
chown -R $JENKINS_USER:$JENKINS_USER $SSH_DIR

# --------------------------------------------------------------------------
# STEP 6: Add jenkins user to docker group
# --------------------------------------------------------------------------
echo "=== Adding jenkins to docker group ==="
if getent group docker > /dev/null; then
  usermod -aG docker $JENKINS_USER
  echo "Added jenkins to docker group"
else
  echo "Docker group does not exist"
fi

# --------------------------------------------------------------------------
# STEP 7: Create workspace directory
# --------------------------------------------------------------------------
echo "=== Creating workspace directory ==="
WORKSPACE_DIR="$JENKINS_HOME/workspace"
mkdir -p $WORKSPACE_DIR
chown $JENKINS_USER:$JENKINS_USER $WORKSPACE_DIR

# --------------------------------------------------------------------------
# STEP 8: Ensure SSH service is running
# --------------------------------------------------------------------------
echo "=== Ensuring SSH service is running ==="
systemctl enable ssh
systemctl start ssh

# Verify SSH is listening
if systemctl is-active --quiet ssh; then
  echo "SSH service is running"
else
  echo "ERROR: SSH service failed to start"
  exit 1
fi

# --------------------------------------------------------------------------
# STEP 9: Display status
# --------------------------------------------------------------------------
echo "=== Agent setup complete ==="
echo "Jenkins User: $JENKINS_USER"
echo "Jenkins Home: $JENKINS_HOME"
echo "SSH Directory: $SSH_DIR"
echo "Authorized Keys: $(wc -l < $AUTHORIZED_KEYS) key(s)"
echo "SSH Status: $(systemctl is-active ssh)"
echo "Docker Status: $(systemctl is-active docker || echo 'not installed')"
echo "Timestamp: $(date)"

# --------------------------------------------------------------------------
# VERIFICATION: Test that SSH is properly configured
# --------------------------------------------------------------------------
echo "=== SSH Configuration Verification ==="
echo "SSH directory permissions: $(stat -c '%a' $SSH_DIR)"
echo "authorized_keys permissions: $(stat -c '%a' $AUTHORIZED_KEYS)"
echo "authorized_keys owner: $(stat -c '%U:%G' $AUTHORIZED_KEYS)"
