# ============================================================================
# PACKER TEMPLATE - Jenkins Agent AMI
# ============================================================================
# PURPOSE: Build an AMI for Jenkins Agent (Slave) nodes
# LOCATION: packer/jenkins-agent.pkr.hcl
# USAGE: packer build jenkins-agent.pkr.hcl
# OUTPUT: AMI ID (ami-xxxxxxxxx) for use in Terraform
# ============================================================================
#
# KEY DIFFERENCE FROM CONTROLLER:
# - NO Jenkins server installed
# - Includes build tools (Docker, Maven, Node.js, Python)
# - Lighter image = faster launch time
# - Used by EC2 plugin for on-demand agents
#
# WHAT THIS TEMPLATE CREATES:
# - Ubuntu 22.04 base
# - Java 17 JDK (required for Jenkins agent)
# - Docker (for containerized builds)
# - Maven (for Java builds)
# - Node.js (for JavaScript builds)
# - Python 3 (for Python builds and scripting)
# - SSH configured for controller connection
#
# NOTE: Packer configuration (required_plugins) is in variables.pkr.hcl
#
# ============================================================================

# ============================================================================
# DATA SOURCES
# ============================================================================

# Find latest Ubuntu 22.04 AMI for Agent
# NOTE: Named "ubuntu_agent" to avoid conflict with controller template
data "amazon-ami" "ubuntu_agent" {
  filters = {
    name                = var.source_ami_name_filter
    virtualization-type = "hvm"
    root-device-type    = "ebs"
  }

  owners      = [var.source_ami_owner]
  most_recent = true
  region      = var.aws_region
}

# ============================================================================
# SOURCE BLOCK - Amazon EBS Builder
# ============================================================================

source "amazon-ebs" "jenkins_agent" {
  # --------------------------------------------------------------------------
  # AMI CONFIGURATION
  # --------------------------------------------------------------------------

  # Name of the output AMI
  # FORMAT: jenkins-agent-{timestamp}
  ami_name = "${var.ami_name_prefix}-agent-${formatdate("YYYYMMDD-hhmmss", timestamp())}"

  # Description
  ami_description = "Jenkins Agent AMI - Ubuntu 22.04 with build tools pre-installed"

  # --------------------------------------------------------------------------
  # SOURCE IMAGE
  # --------------------------------------------------------------------------

  source_ami = data.amazon-ami.ubuntu_agent.id

  # --------------------------------------------------------------------------
  # INSTANCE CONFIGURATION
  # --------------------------------------------------------------------------

  # Instance type for building
  # NOTE: Agent AMI can use smaller instance since no Jenkins server
  instance_type = var.build_instance_type

  region  = var.aws_region
  profile = var.aws_profile

  # --------------------------------------------------------------------------
  # NETWORK CONFIGURATION
  # --------------------------------------------------------------------------

  vpc_id                      = var.vpc_id
  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip

  # --------------------------------------------------------------------------
  # SSH CONFIGURATION
  # --------------------------------------------------------------------------

  ssh_username           = var.ssh_username
  ssh_timeout            = "10m"
  ssh_handshake_attempts = 100

  # --------------------------------------------------------------------------
  # AMI SETTINGS
  # --------------------------------------------------------------------------

  force_deregister      = var.force_deregister
  force_delete_snapshot = var.force_delete_snapshot
  skip_create_ami       = var.skip_create_ami

  # Encrypt the AMI
  encrypt_boot = true

  # --------------------------------------------------------------------------
  # TAGS
  # --------------------------------------------------------------------------

  tags = {
    Name        = "${var.ami_name_prefix}-agent"
    Project     = var.project_name
    Environment = var.environment
    NodeType    = "agent"
    BuildTime   = timestamp()
    SourceAMI   = data.amazon-ami.ubuntu_agent.id
    OS          = "Ubuntu 22.04"
    ManagedBy   = "Packer"
    # Agent-specific tags
    HasDocker   = "true"
    HasMaven    = "true"
    HasNodeJS   = "true"
    HasPython   = "true"
  }

  snapshot_tags = {
    Name        = "${var.ami_name_prefix}-agent-snapshot"
    Project     = var.project_name
    Environment = var.environment
  }

  run_tags = {
    Name    = "packer-build-jenkins-agent"
    Purpose = "AMI Build"
  }
}

# ============================================================================
# BUILD BLOCK
# ============================================================================

build {
  sources = ["source.amazon-ebs.jenkins_agent"]

  # --------------------------------------------------------------------------
  # PROVISIONER 1: Wait for cloud-init
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
  # NOTE: Uses jenkins-agent.yml playbook (NOT controller)
  # --------------------------------------------------------------------------
  provisioner "ansible" {
    playbook_file = var.ansible_playbook_agent

    user = var.ssh_username

    extra_arguments = concat(
      var.ansible_extra_arguments,
      [
        # Load group variables (contains common_packages, java_version, etc.)
        "-e", "@../ansible/group_vars/all.yml",
        # Pass variables to Ansible
        "-e", "node_type=agent",
        # Enable all build tools
        "-e", "install_docker=true",
        "-e", "install_maven=true",
        "-e", "install_nodejs=true",
        "-e", "install_python=true",
      ]
    )

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
  # PROVISIONER 5: Verify installations
  # --------------------------------------------------------------------------
  # WHY: Confirm all tools are installed before creating AMI
  # --------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "echo '=== Verifying installations ==='",

      # Verify Java
      "echo 'Java version:'",
      "java -version",

      # Verify Docker
      "echo 'Docker version:'",
      "docker --version",

      # Verify Maven
      "echo 'Maven version:'",
      "mvn --version",

      # Verify Node.js
      "echo 'Node.js version:'",
      "node --version",
      "npm --version",

      # Verify Python
      "echo 'Python version:'",
      "python3 --version",

      "echo '=== All verifications passed ==='"
    ]
  }

  # --------------------------------------------------------------------------
  # PROVISIONER 6: Cleanup before creating AMI
  # --------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "echo '=== Cleaning up for AMI creation ==='",

      # Clear apt cache
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",

      # Clear Docker cache (can be large)
      "sudo docker system prune -af || true",

      # Clear temporary files
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",

      # Clear logs
      "sudo find /var/log -type f -exec truncate -s 0 {} \\;",

      # Clear bash history (don't use 'history -c' as it's a shell builtin)
      "rm -f ~/.bash_history",
      "rm -f /home/*/.bash_history || true",

      # Clear SSH host keys
      "sudo rm -f /etc/ssh/ssh_host_*",

      # Clear machine-id
      "sudo truncate -s 0 /etc/machine-id",

      # Clear npm cache
      "sudo rm -rf /root/.npm || true",
      "rm -rf ~/.npm || true",

      # Clear pip cache
      "sudo rm -rf /root/.cache/pip || true",
      "rm -rf ~/.cache/pip || true",

      "echo '=== Cleanup complete ==='"
    ]
  }

  # --------------------------------------------------------------------------
  # POST-PROCESSOR: Manifest
  # --------------------------------------------------------------------------
  post-processor "manifest" {
    output     = "manifest-agent.json"
    strip_path = true
    custom_data = {
      node_type   = "agent"
      environment = var.environment
      source_ami  = data.amazon-ami.ubuntu_agent.id
      tools       = "docker,maven,nodejs,python"
    }
  }
}

# ============================================================================
# USAGE EXAMPLES
# ============================================================================
#
# 1. Initialize Packer:
#    packer init jenkins-agent.pkr.hcl
#
# 2. Validate template:
#    packer validate jenkins-agent.pkr.hcl
#
# 3. Build AMI:
#    packer build jenkins-agent.pkr.hcl
#
# 4. Build without Docker (lighter image):
#    packer build \
#      -var="ansible_extra_arguments=[\"-v\", \"-e\", \"install_docker=false\"]" \
#      jenkins-agent.pkr.hcl
#
# 5. Build both AMIs in parallel:
#    packer build jenkins-controller.pkr.hcl &
#    packer build jenkins-agent.pkr.hcl &
#    wait
#
# ============================================================================
