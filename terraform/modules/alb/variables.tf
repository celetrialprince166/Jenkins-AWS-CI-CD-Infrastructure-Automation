# ============================================================================
# ALB MODULE - Variables
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
  description = "IDs of subnets for ALB"
}

variable "security_group_id" {
  type        = string
  description = "ID of the ALB security group"
}

variable "jenkins_http_port" {
  type        = number
  description = "Jenkins HTTP port"
  default     = 8080
}

variable "health_check_path" {
  type        = string
  description = "Path for health check"
  default     = "/login"
}

variable "certificate_arn" {
  type        = string
  description = "ARN of ACM certificate for HTTPS"
  default     = null
}

variable "internal" {
  type        = bool
  description = "Whether ALB is internal"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
