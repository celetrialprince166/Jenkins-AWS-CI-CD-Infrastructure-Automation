# ============================================================================
# SECURITY GROUPS MODULE - Variables
# ============================================================================
# LOCATION: terraform/modules/security-groups/variables.tf
# ============================================================================

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block of the VPC"
}

variable "jenkins_http_port" {
  type        = number
  description = "Jenkins HTTP port"
  default     = 8080
}

variable "jenkins_agent_port" {
  type        = number
  description = "Jenkins agent (JNLP) port"
  default     = 50000
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
