# ============================================================================
# TERRAFORM BOOTSTRAP - Remote State Infrastructure
# ============================================================================
# PURPOSE: Create S3 bucket for Terraform remote state
# LOCATION: terraform/bootstrap/main.tf
# ============================================================================
#
# USAGE:
# 1. cd terraform/bootstrap
# 2. terraform init
# 3. terraform apply
# 4. Copy the outputs to configure backend in ../backend.tf
# 5. Run terraform init -migrate-state in parent directory
#
# NOTE: This is a one-time setup. Once created, don't destroy these resources
#       unless you want to lose all Terraform state!
#
# UPDATE (Terraform 1.10+):
# - DynamoDB is NO LONGER NEEDED for state locking
# - S3 native locking via use_lockfile = true
# - Simpler setup, lower cost, fewer permissions needed
#
# ============================================================================

terraform {
  required_version = ">= 1.10.0"  # Required for use_lockfile

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bootstrap uses local state (chicken-and-egg problem)
  # This state should be committed to git or stored securely
}

# ============================================================================
# VARIABLES
# ============================================================================

variable "aws_region" {
  type        = string
  description = "AWS region for state resources"
  default     = "eu-west-1"
}

variable "project_name" {
  type        = string
  description = "Project name for resource naming"
  default     = "jenkins"
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "shared"
}

# ============================================================================
# PROVIDER
# ============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Purpose     = "Terraform State Management"
    }
  }
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "aws_caller_identity" "current" {}

# ============================================================================
# LOCALS
# ============================================================================

locals {
  bucket_name = "${var.project_name}-terraform-state-${data.aws_caller_identity.current.account_id}"
}

# ============================================================================
# S3 BUCKET - State Storage
# ============================================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.bucket_name

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = local.bucket_name
  }
}

# Enable versioning for state history and recovery
# CRITICAL: This is required for state recovery!
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule to clean up old versions
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    # Keep 90 days of state history for recovery
    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    # Clean up incomplete uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "backend_config" {
  description = "Backend configuration to add to backend.tf"
  value       = <<-EOT
    
    # ==========================================================================
    # Add this to terraform/backend.tf (uncomment the backend block):
    # ==========================================================================
    
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.terraform_state.id}"
        key          = "jenkins-infrastructure/terraform.tfstate"
        region       = "${var.aws_region}"
        encrypt      = true
        use_lockfile = true  # S3 native locking (Terraform 1.10+)
      }
    }
    
    # Then run: terraform init -migrate-state
    
  EOT
}

# ============================================================================
# IAM POLICY - For CI/CD Access
# ============================================================================
# This policy can be attached to the CI/CD IAM user/role
# NOTE: No DynamoDB permissions needed with use_lockfile!

resource "aws_iam_policy" "terraform_state_access" {
  name        = "${var.project_name}-terraform-state-access"
  description = "Policy for accessing Terraform state in S3 (with native locking)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ListBucket"
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Sid    = "S3StateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/jenkins-infrastructure/terraform.tfstate"
      },
      {
        Sid    = "S3LockFileAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/jenkins-infrastructure/terraform.tfstate.tflock"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-terraform-state-access"
  }
}

output "state_access_policy_arn" {
  description = "ARN of the IAM policy for state access (attach to CI/CD role)"
  value       = aws_iam_policy.terraform_state_access.arn
}

# ============================================================================
# MIGRATION FROM DYNAMODB (If you have existing DynamoDB-based locking)
# ============================================================================
#
# If you're migrating from an older setup with DynamoDB:
#
# 1. Update your backend.tf:
#    - Remove: dynamodb_table = "your-table"
#    - Add:    use_lockfile = true
#
# 2. Run: terraform init -migrate-state
#
# 3. After confirming everything works, you can delete the DynamoDB table
#    to save costs (it's no longer needed)
#
# ============================================================================
