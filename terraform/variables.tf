# ============================================================================
# TERRAFORM VARIABLES - Root Module
# ============================================================================
# PURPOSE: Define input variables for the Jenkins infrastructure
# LOCATION: terraform/variables.tf
# USAGE: Override with terraform.tfvars or -var flag
# ============================================================================

# ============================================================================
# GENERAL CONFIGURATION
# ============================================================================

variable "project_name" {
  type        = string
  description = "Name of the project (used for resource naming and tagging)"
  default     = "jenkins"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "Project name must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# ============================================================================
# AWS CONFIGURATION
# ============================================================================

variable "aws_region" {
  type        = string
  description = "AWS region for all resources"
  default     = "eu-west-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile to use (null for default credential chain)"
  default     = null
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones to use (minimum 2 for HA)"
  default     = ["eu-west-1a", "eu-west-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required for high availability."
  }
}

# ============================================================================
# VPC CONFIGURATION
# ============================================================================

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets (one per AZ)"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets (one per AZ)"
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

# ============================================================================
# JENKINS CONTROLLER CONFIGURATION
# ============================================================================

variable "controller_ami_id" {
  type        = string
  description = "AMI ID for Jenkins controller (from Packer build)"
  default     = "ami-030221be5662ce1a5"
  # No default - must be provided
}

variable "controller_instance_type" {
  type        = string
  description = "EC2 instance type for Jenkins controller"
  default     = "t3.medium"
}

variable "controller_min_size" {
  type        = number
  description = "Minimum number of controller instances"
  default     = 2
}

variable "controller_max_size" {
  type        = number
  description = "Maximum number of controller instances"
  default     = 4
}

variable "controller_desired_size" {
  type        = number
  description = "Desired number of controller instances"
  default     = 2
}

variable "controller_volume_size" {
  type        = number
  description = "Root volume size for controller (GB)"
  default     = 30
}

# ============================================================================
# JENKINS AGENT CONFIGURATION
# ============================================================================

variable "agent_ami_id" {
  type        = string
  description = "AMI ID for Jenkins agent (from Packer build)"
  default = "ami-0ce613c152da76879"
  # No default - must be provided
}

variable "agent_instance_type" {
  type        = string
  description = "EC2 instance type for Jenkins agents"
  default     = "t3.medium"
}

variable "agent_min_size" {
  type        = number
  description = "Minimum number of agent instances"
  default     = 2
}

variable "agent_max_size" {
  type        = number
  description = "Maximum number of agent instances"
  default     = 5
}

variable "agent_desired_size" {
  type        = number
  description = "Desired number of agent instances"
  default     = 2
}

variable "agent_volume_size" {
  type        = number
  description = "Root volume size for agents (GB)"
  default     = 50
}

# ============================================================================
# JENKINS CONFIGURATION
# ============================================================================

variable "jenkins_http_port" {
  type        = number
  description = "HTTP port for Jenkins web UI"
  default     = 8080
}

variable "jenkins_agent_port" {
  type        = number
  description = "Port for Jenkins agent (JNLP) connections"
  default     = 50000
}

# ============================================================================
# AUTO SCALING CONFIGURATION
# ============================================================================

variable "controller_cpu_target" {
  type        = number
  description = "Target CPU utilization (%) for controller auto-scaling"
  default     = 60
}

variable "agent_cpu_target" {
  type        = number
  description = "Target CPU utilization (%) for agent auto-scaling"
  default     = 50
}

# ============================================================================
# EFS CONFIGURATION
# ============================================================================

variable "efs_performance_mode" {
  type        = string
  description = "EFS performance mode (generalPurpose or maxIO)"
  default     = "generalPurpose"

  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.efs_performance_mode)
    error_message = "EFS performance mode must be generalPurpose or maxIO."
  }
}

variable "efs_throughput_mode" {
  type        = string
  description = "EFS throughput mode (bursting, provisioned, or elastic)"
  default     = "bursting"

  validation {
    condition     = contains(["bursting", "provisioned", "elastic"], var.efs_throughput_mode)
    error_message = "EFS throughput mode must be bursting, provisioned, or elastic."
  }
}

variable "efs_encrypted" {
  type        = bool
  description = "Whether to encrypt EFS at rest"
  default     = true
}

# ============================================================================
# ALB CONFIGURATION
# ============================================================================

variable "alb_internal" {
  type        = bool
  description = "Whether the ALB is internal (not internet-facing)"
  default     = false
}

variable "alb_certificate_arn" {
  type        = string
  description = "ARN of ACM certificate for HTTPS (optional)"
  default     = null
}

variable "health_check_path" {
  type        = string
  description = "Path for ALB health check"
  default     = "/login"
}

# ============================================================================
# SSH KEY CONFIGURATION
# ============================================================================

variable "key_name" {
  type        = string
  description = "Name of existing EC2 key pair for SSH access (optional)"
  default     = null
}

variable "create_ssh_key" {
  type        = bool
  description = "Whether to create a new SSH key pair"
  default     = true
}

# ============================================================================
# TAGS
# ============================================================================

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}
