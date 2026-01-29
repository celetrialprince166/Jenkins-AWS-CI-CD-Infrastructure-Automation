# ============================================================================
# IAM MODULE - Variables
# ============================================================================
# LOCATION: terraform/modules/iam/variables.tf
# ============================================================================

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "efs_arn" {
  type        = string
  description = "ARN of the EFS file system"
}

variable "agent_ssh_key_secret_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret containing the agent SSH private key"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
