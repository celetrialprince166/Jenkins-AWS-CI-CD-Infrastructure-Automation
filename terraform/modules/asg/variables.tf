# ============================================================================
# ASG MODULE - Variables
# ============================================================================
variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "controller_ami_id" {
  type        = string
  description = "AMI ID for controller"
}

variable "agent_ami_id" {
  type        = string
  description = "AMI ID for agent"
}

variable "controller_instance_type" {
  type        = string
  description = "Instance type for controller"
}

variable "agent_instance_type" {
  type        = string
  description = "Instance type for agent"
}

variable "controller_security_group_id" {
  type        = string
  description = "Security group ID for controller"
}

variable "agent_security_group_id" {
  type        = string
  description = "Security group ID for agent"
}

variable "controller_instance_profile_name" {
  type        = string
  description = "Instance profile name for controller"
}

variable "agent_instance_profile_name" {
  type        = string
  description = "Instance profile name for agent"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for instances"
}

variable "target_group_arn" {
  type        = string
  description = "Target group ARN for ALB"
}

variable "controller_min_size" {
  type        = number
  description = "Minimum controller instances"
  default     = 1
}

variable "controller_max_size" {
  type        = number
  description = "Maximum controller instances"
  default     = 2
}

variable "controller_desired_size" {
  type        = number
  description = "Desired controller instances"
  default     = 1
}

variable "agent_min_size" {
  type        = number
  description = "Minimum agent instances"
  default     = 0
}

variable "agent_max_size" {
  type        = number
  description = "Maximum agent instances"
  default     = 5
}

variable "agent_desired_size" {
  type        = number
  description = "Desired agent instances"
  default     = 1
}

variable "controller_volume_size" {
  type        = number
  description = "Root volume size for controller (GB)"
  default     = 30
}

variable "agent_volume_size" {
  type        = number
  description = "Root volume size for agent (GB)"
  default     = 50
}

variable "key_name" {
  type        = string
  description = "SSH key pair name"
  default     = null
}

variable "controller_user_data" {
  type        = string
  description = "User data script for controller"
  default     = ""
}

variable "agent_user_data" {
  type        = string
  description = "User data script for agent"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

# ============================================================================
# TARGET TRACKING SCALING VARIABLES
# ============================================================================

variable "agent_cpu_target" {
  type        = number
  description = "Target CPU utilization (%) for agent auto-scaling. Lower = more aggressive scaling."
  default     = 50

  validation {
    condition     = var.agent_cpu_target >= 20 && var.agent_cpu_target <= 90
    error_message = "Agent CPU target must be between 20 and 90 percent."
  }
}

variable "controller_cpu_target" {
  type        = number
  description = "Target CPU utilization (%) for controller auto-scaling. Higher = less aggressive scaling."
  default     = 60

  validation {
    condition     = var.controller_cpu_target >= 20 && var.controller_cpu_target <= 90
    error_message = "Controller CPU target must be between 20 and 90 percent."
  }
}
