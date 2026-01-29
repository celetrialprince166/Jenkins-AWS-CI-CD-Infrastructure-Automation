# ============================================================================
# PACKER TEMPLATE - Jenkins Controller AMI
# ============================================================================
# PURPOSE: Build an AMI with Jenkins Controller (Master) pre-installed
# LOCATION: packer/jenkins-controller.pkr.hcl
# USAGE: packer build jenkins-controller.pkr.hcl
# OUTPUT: AMI ID (ami-xxxxxxxxx) for use in Terraform
# ============================================================================
#
# WHAT THIS TEMPLATE CREATES:
# - Ubuntu 22.04 base
# - Java 17 JDK
# - Jenkins server (latest LTS)
# - Jenkins plugins (pre-installed)
# - System optimizations
#
# WHAT THIS TEMPLATE DOES NOT DO:
# - Mount EFS (done at runtime via user_data)
# - Configure Jenkins jobs (done via JCasC or UI)
# - Set up SSL (done via ALB)
#
# NOTE: Packer configuration (required_plugins) is in variables.pkr.hcl
#
# ============================================================================

# ============================================================================
# DATA SOURCES
# ============================================================================
# Query AWS for information needed during build
# ============================================================================

# FIND LATEST UBUNTU AMI FOR CONTROLLER
# --------------------------------------
# WHY: We want the latest Ubuntu 22.04 AMI with security patches
# HOW: Filter by name pattern and owner, get most recent
# BENEFIT: Always builds on latest base image without hardcoding AMI ID
# NOTE: Named "ubuntu_controller" to avoid conflict with agent template
data "amazon-ami" "ubuntu_controller" {
  filters = {
    # Match Ubuntu 22.04 (Jammy) server images
    name                = var.source_ami_name_filter
    # Only HVM virtualization (required for modern instance types)
    virtualization-type = "hvm"
    # EBS-backed (not instance-store)
    root-device-type    = "ebs"
  }

  # Only AMIs from Canonical (Ubuntu's official publisher)
  owners = [var.source_ami_owner]

  # Get the most recent matching AMI
  most_recent = true

  # Region to search in
  region = var.aws_region
}

# ============================================================================
# SOURCE BLOCK - Amazon EBS Builder
# ============================================================================
# Defines HOW to build the AMI (launch instance, configure, snapshot)
# ============================================================================

source "amazon-ebs" "jenkins_controller" {
  # --------------------------------------------------------------------------
  # AMI CONFIGURATION
  # --------------------------------------------------------------------------

  # Name of the output AMI
  # FORMAT: jenkins-controller-{timestamp}
  # WHY: Timestamp ensures unique names, easy to identify build time
  ami_name = "${var.ami_name_prefix}-controller-${formatdate("YYYYMMDD-hhmmss", timestamp())}"

  # Description for the AMI
  ami_description = "Jenkins Controller AMI - Ubuntu 22.04 with Jenkins pre-installed"

  # --------------------------------------------------------------------------
  # SOURCE IMAGE
  # --------------------------------------------------------------------------

  # Use the AMI found by our data source
  source_ami = data.amazon-ami.ubuntu_controller.id

  # --------------------------------------------------------------------------
  # INSTANCE CONFIGURATION
  # --------------------------------------------------------------------------

  # Instance type for building
  # WHY: t3.medium provides good balance of speed and cost
  instance_type = var.build_instance_type

  # Region to build in
  region = var.aws_region

  # AWS profile (null = use env vars or IAM role)
  profile = var.aws_profile

  # --------------------------------------------------------------------------
  # NETWORK CONFIGURATION
  # --------------------------------------------------------------------------

  # VPC and subnet (null = use defaults)
  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  # Assign public IP for SSH access
  associate_public_ip_address = var.associate_public_ip

  # --------------------------------------------------------------------------
  # SSH CONFIGURATION
  # --------------------------------------------------------------------------

  # Username for SSH connection
  ssh_username = var.ssh_username

  # SSH timeout - how long to wait for instance to be ready
  # WHY: 10 minutes should be enough for instance to boot
  ssh_timeout = "10m"

  # SSH handshake attempts
  ssh_handshake_attempts = 100

  # --------------------------------------------------------------------------
  # AMI SETTINGS
  # --------------------------------------------------------------------------

  # Force deregister existing AMI with same name
  force_deregister = var.force_deregister

  # Delete snapshot when deregistering
  force_delete_snapshot = var.force_delete_snapshot

  # Skip AMI creation (for testing)
  skip_create_ami = var.skip_create_ami

  # Encrypt the AMI
  # WHY: Security best practice - data at rest encryption
  encrypt_boot = true

  # --------------------------------------------------------------------------
  # TAGS
  # --------------------------------------------------------------------------
  # Tags applied to the AMI and snapshots

  tags = {
    Name        = "${var.ami_name_prefix}-controller"
    Project     = var.project_name
    Environment = var.environment
    NodeType    = "controller"
    BuildTime   = timestamp()
    SourceAMI   = data.amazon-ami.ubuntu_controller.id
    OS          = "Ubuntu 22.04"
    ManagedBy   = "Packer"
  }

  # Tags for the snapshot
  snapshot_tags = {
    Name        = "${var.ami_name_prefix}-controller-snapshot"
    Project     = var.project_name
    Environment = var.environment
  }

  # Tags for the temporary build instance
  run_tags = {
    Name    = "packer-build-jenkins-controller"
    Purpose = "AMI Build"
  }
}

# ============================================================================
# BUILD BLOCK
# ============================================================================
# Defines WHAT to do with the instance (provisioners)
# ============================================================================

build {
  # Use the source defined above
  sources = ["source.amazon-ebs.jenkins_controller"]

  # --------------------------------------------------------------------------
  # PROVISIONER 1: Wait for cloud-init
  # --------------------------------------------------------------------------
  # WHY: Cloud-init runs on first boot to configure the instance
  #      We must wait for it to complete before installing packages
  # HOW: Run cloud-init status --wait which blocks until complete
  # --------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "echo '=== Waiting for cloud-init to complete ==='",
      "sudo cloud-init status --wait",
      "echo '=== Cloud-init complete ==='"
    ]
  }

  # --------------------------------------------------------------------------
  # PROVISIONER 2: Update system packages
  # --------------------------------------------------------------------------
  # WHY: Ensure we have latest security patches before installing Jenkins
  # HOW: Run apt update and upgrade
  # --------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "echo '=== Updating system packages ==='",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "echo '=== System packages updated ==='"
    ]
  }

  # --------------------------------------------------------------------------
  # PROVISIONER 3: Install Ansible dependencies
  # --------------------------------------------------------------------------
  # WHY: Ansible provisioner needs Python on the target
  # HOW: Install Python 3 and pip
  # NOTE: Ubuntu 22.04 has Python 3 by default, but ensure pip is there
  # --------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "echo '=== Installing Ansible dependencies ==='",
      "sudo apt-get install -y python3 python3-pip python3-apt",
      "echo '=== Ansible dependencies installed ==='"
    ]
  }

  # --------------------------------------------------------------------------
  # PROVISIONER 4: Run Ansible playbook
  # --------------------------------------------------------------------------
  # WHY: Ansible does the actual configuration (Java, Jenkins, etc.)
  # HOW: Packer runs ansible-playbook against the build instance
  # PLAYBOOK: ../ansible/playbooks/jenkins-controller.yml
  # --------------------------------------------------------------------------
  provisioner "ansible" {
    # Path to the playbook (relative to this file)
    playbook_file = var.ansible_playbook_controller

    # User to connect as
    user = var.ssh_username

    # Extra arguments for ansible-playbook
    extra_arguments = concat(
      var.ansible_extra_arguments,
      [
        # Load group variables (contains common_packages, java_version, etc.)
        "-e", "@../ansible/group_vars/all.yml",
        # Pass variables to Ansible
        "-e", "node_type=controller",
        "-e", "mount_efs=false",      # Don't mount EFS during build
        "-e", "skip_efs_role=true",   # Skip EFS role entirely
      ]
    )

    # Use SSH connection (not local)
    use_proxy = false

    # Ansible configuration
    # IMPORTANT: Set ANSIBLE_ROLES_PATH to find roles relative to ansible/ directory
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_STDOUT_CALLBACK=yaml",
      "ANSIBLE_ROLES_PATH=../ansible/roles",
    ]
  }

  # --------------------------------------------------------------------------
  # PROVISIONER 5: Cleanup before creating AMI
  # --------------------------------------------------------------------------
  # WHY: Remove temporary files, logs, and sensitive data
  #      Smaller AMI = faster launch time
  # HOW: Delete caches, logs, and temporary files
  # --------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "echo '=== Cleaning up for AMI creation ==='",

      # Clear apt cache
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",

      # Clear temporary files
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",

      # Clear logs (but keep structure)
      "sudo find /var/log -type f -exec truncate -s 0 {} \\;",

      # Clear bash history (don't use 'history -c' as it's a shell builtin)
      "rm -f ~/.bash_history",
      "rm -f /home/*/.bash_history || true",

      # Clear SSH host keys (will be regenerated on first boot)
      "sudo rm -f /etc/ssh/ssh_host_*",

      # Clear machine-id (will be regenerated on first boot)
      "sudo truncate -s 0 /etc/machine-id",

      "echo '=== Cleanup complete ==='"
    ]
  }

  # --------------------------------------------------------------------------
  # POST-PROCESSOR: Manifest
  # --------------------------------------------------------------------------
  # WHY: Creates a JSON file with build information
  # USE: CI/CD can read this to get the AMI ID
  # --------------------------------------------------------------------------
  post-processor "manifest" {
    output     = "manifest-controller.json"
    strip_path = true
    custom_data = {
      node_type   = "controller"
      environment = var.environment
      source_ami  = data.amazon-ami.ubuntu_controller.id
    }
  }
}

# ============================================================================
# USAGE EXAMPLES
# ============================================================================
#
# 1. Initialize Packer (download plugins):
#    packer init jenkins-controller.pkr.hcl
#
# 2. Validate template:
#    packer validate jenkins-controller.pkr.hcl
#
# 3. Build AMI (default settings):
#    packer build jenkins-controller.pkr.hcl
#
# 4. Build with custom region:
#    packer build -var="aws_region=eu-west-1" jenkins-controller.pkr.hcl
#
# 5. Build for production:
#    packer build -var="environment=prod" jenkins-controller.pkr.hcl
#
# 6. Debug mode (verbose):
#    packer build -debug jenkins-controller.pkr.hcl
#
# 7. Test Ansible without creating AMI:
#    packer build -var="skip_create_ami=true" jenkins-controller.pkr.hcl
#
# ============================================================================
