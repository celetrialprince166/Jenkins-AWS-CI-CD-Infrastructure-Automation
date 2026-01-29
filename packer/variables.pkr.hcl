# ============================================================================
# PACKER VARIABLES - Shared Variable Definitions
# ============================================================================
# PURPOSE: Define variables used by all Packer templates
# LOCATION: packer/variables.pkr.hcl
# USAGE: Override with -var or -var-file flags
# DOCS: https://developer.hashicorp.com/packer/docs/templates/hcl_templates/variables
# ============================================================================

# ============================================================================
# PACKER CONFIGURATION (Shared)
# ============================================================================
# Required Packer version and plugins - defined once for all templates
# ============================================================================

packer {
  # Minimum Packer version required
  required_version = ">= 1.9.0"

  # Required plugins
  required_plugins {
    # Amazon plugin for building EC2 AMIs
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }

    # Ansible plugin for configuration management
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# ============================================================================
# AWS CONFIGURATION
# ============================================================================
# These variables configure where and how Packer builds AMIs
# ============================================================================

# AWS REGION
# ----------
# WHAT: AWS region where AMI will be built and stored
# WHY: AMIs are region-specific - build in the region you'll deploy to
# DEFAULT: us-east-1 (N. Virginia) - most common, has all services
# OVERRIDE: -var="aws_region=eu-west-1"
variable "aws_region" {
  type        = string
  description = "AWS region where the AMI will be built"
  default     = "eu-west-1"
}

# AWS PROFILE
# -----------
# WHAT: AWS CLI profile to use for authentication
# WHY: Allows using different AWS accounts/credentials
# DEFAULT: "default" - uses default AWS CLI profile
# OVERRIDE: -var="aws_profile=production"
# NOTE: Set to null to use environment variables or IAM role
variable "aws_profile" {
  type        = string
  description = "AWS CLI profile to use (null for env vars/IAM role)"
  default     = null
}

# ============================================================================
# SOURCE AMI CONFIGURATION
# ============================================================================
# These variables define the base image Packer starts from
# ============================================================================

# SOURCE AMI FILTER - NAME
# ------------------------
# WHAT: Pattern to match when finding the base AMI
# WHY: We want the latest Ubuntu 22.04 LTS (Jammy) AMI
# FORMAT: Uses wildcards (*) to match any version
# NOTE: This finds official Canonical Ubuntu AMIs
variable "source_ami_name_filter" {
  type        = string
  description = "AMI name filter pattern for source image"
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}

# SOURCE AMI OWNER
# ----------------
# WHAT: AWS account ID that owns the source AMI
# WHY: Ensures we get official AMIs, not community/malicious ones
# VALUE: 099720109477 = Canonical (Ubuntu's publisher)
# SECURITY: Always verify AMI owner to prevent supply chain attacks
variable "source_ami_owner" {
  type        = string
  description = "AWS account ID of the source AMI owner"
  default     = "099720109477" # Canonical (Ubuntu)
}

# ============================================================================
# INSTANCE CONFIGURATION
# ============================================================================
# These variables configure the temporary EC2 instance used for building
# ============================================================================

# INSTANCE TYPE
# -------------
# WHAT: EC2 instance type for the build process
# WHY: Larger instance = faster build (more CPU/RAM for compilation)
# COST: Only runs during build (typically 10-20 minutes)
# OPTIONS:
#   - t3.micro  : Cheapest, slow builds
#   - t3.medium : Good balance (recommended)
#   - t3.large  : Faster builds, higher cost
variable "build_instance_type" {
  type        = string
  description = "EC2 instance type for building the AMI"
  default     = "t3.medium"
}

# SSH USERNAME
# ------------
# WHAT: Username for SSH connection to build instance
# WHY: Different AMIs have different default users
# VALUES:
#   - ubuntu    : Ubuntu AMIs
#   - ec2-user  : Amazon Linux AMIs
#   - centos    : CentOS AMIs
variable "ssh_username" {
  type        = string
  description = "SSH username for connecting to the build instance"
  default     = "ubuntu"
}

# ============================================================================
# AMI NAMING AND TAGGING
# ============================================================================
# These variables control how the output AMI is named and tagged
# ============================================================================

# AMI NAME PREFIX
# ---------------
# WHAT: Prefix for the AMI name
# WHY: Makes AMIs easy to identify and filter
# FORMAT: {prefix}-{timestamp}
# EXAMPLE: jenkins-controller-1706123456
variable "ami_name_prefix" {
  type        = string
  description = "Prefix for the AMI name"
  default     = "jenkins"
}

# ENVIRONMENT
# -----------
# WHAT: Environment tag for the AMI
# WHY: Distinguish between dev/staging/prod AMIs
# USAGE: Used in AMI tags and can affect Ansible variables
variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  default     = "dev"
}

# PROJECT NAME
# ------------
# WHAT: Project identifier for tagging
# WHY: Helps with cost allocation and resource organization
variable "project_name" {
  type        = string
  description = "Project name for tagging"
  default     = "jenkins-infrastructure"
}

# ============================================================================
# ANSIBLE CONFIGURATION
# ============================================================================
# These variables configure how Packer runs Ansible
# ============================================================================

# ANSIBLE PLAYBOOK PATH - CONTROLLER
# ----------------------------------
# WHAT: Path to the Ansible playbook for controller AMI
# WHY: Packer needs to know which playbook to run
# RELATIVE: Path is relative to the packer/ directory
variable "ansible_playbook_controller" {
  type        = string
  description = "Path to Ansible playbook for controller"
  default     = "../ansible/playbooks/jenkins-controller.yml"
}

# ANSIBLE PLAYBOOK PATH - AGENT
# -----------------------------
# WHAT: Path to the Ansible playbook for agent AMI
variable "ansible_playbook_agent" {
  type        = string
  description = "Path to Ansible playbook for agent"
  default     = "../ansible/playbooks/jenkins-agent.yml"
}

# ANSIBLE EXTRA ARGUMENTS
# -----------------------
# WHAT: Additional arguments passed to ansible-playbook
# WHY: Can enable verbose mode, skip tags, etc.
# EXAMPLE: ["-v", "--skip-tags", "slow"]
variable "ansible_extra_arguments" {
  type        = list(string)
  description = "Extra arguments for ansible-playbook command"
  default     = ["-v"] # Verbose mode for debugging
}

# ============================================================================
# BUILD CONFIGURATION
# ============================================================================
# These variables control the build process itself
# ============================================================================

# SKIP CREATE AMI
# ---------------
# WHAT: If true, don't create AMI (for testing Ansible)
# WHY: Useful for debugging - faster iteration
# DEFAULT: false - always create AMI
variable "skip_create_ami" {
  type        = bool
  description = "Skip AMI creation (for testing)"
  default     = false
}

# FORCE DEREGISTER
# ----------------
# WHAT: If true, deregister existing AMI with same name
# WHY: Allows rebuilding AMI without manual cleanup
# CAUTION: Will delete existing AMI!
variable "force_deregister" {
  type        = bool
  description = "Force deregister existing AMI with same name"
  default     = false
}

# FORCE DELETE SNAPSHOT
# ---------------------
# WHAT: If true, delete snapshot when deregistering AMI
# WHY: Snapshots cost money - clean up when replacing AMI
variable "force_delete_snapshot" {
  type        = bool
  description = "Delete snapshot when deregistering AMI"
  default     = false
}

# ============================================================================
# VPC CONFIGURATION (Optional)
# ============================================================================
# By default, Packer uses the default VPC. These allow using a custom VPC.
# ============================================================================

# VPC ID
# ------
# WHAT: VPC to launch build instance in
# WHY: May need specific VPC for security/networking
# DEFAULT: null - use default VPC
variable "vpc_id" {
  type        = string
  description = "VPC ID for build instance (null for default VPC)"
  default     = null
}

# SUBNET ID
# ---------
# WHAT: Subnet to launch build instance in
# WHY: Must be in specified VPC, needs internet access
# DEFAULT: null - Packer chooses automatically
variable "subnet_id" {
  type        = string
  description = "Subnet ID for build instance (null for auto)"
  default     = null
}

# ASSOCIATE PUBLIC IP
# -------------------
# WHAT: Whether to assign public IP to build instance
# WHY: Needed for Packer to SSH in (unless using VPN/bastion)
# DEFAULT: true - required for most setups
variable "associate_public_ip" {
  type        = bool
  description = "Associate public IP with build instance"
  default     = true
}
