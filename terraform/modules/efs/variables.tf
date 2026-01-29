# ============================================================================
# EFS MODULE - Variables
# ============================================================================
# LOCATION: terraform/modules/efs/variables.tf
# ============================================================================

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC"
}

variable "subnet_ids" {
  type        = list(string)
  description = "IDs of subnets for mount targets"
}

variable "security_group_id" {
  type        = string
  description = "ID of the EFS security group"
}

variable "performance_mode" {
  type        = string
  description = "EFS performance mode"
  default     = "generalPurpose"
}

variable "throughput_mode" {
  type        = string
  description = "EFS throughput mode"
  default     = "bursting"
}

variable "encrypted" {
  type        = bool
  description = "Whether to encrypt EFS"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
