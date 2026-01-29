# ============================================================================
# VPC MODULE - Variables
# ============================================================================
# PURPOSE: Input variables for VPC module
# LOCATION: terraform/modules/vpc/variables.tf
# ============================================================================

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
