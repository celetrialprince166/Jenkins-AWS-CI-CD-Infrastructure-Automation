# ============================================================================
# PROVIDER CONFIGURATION
# ============================================================================
# PURPOSE: Configure AWS provider settings
# LOCATION: terraform/providers.tf
# DOCS: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
# ============================================================================

# ============================================================================
# AWS PROVIDER
# ============================================================================
# Configures how Terraform authenticates and interacts with AWS
# ============================================================================

provider "aws" {
  # --------------------------------------------------------------------------
  # REGION
  # --------------------------------------------------------------------------
  # WHAT: AWS region where resources will be created
  # WHY: All resources are region-specific
  # VALUE: Comes from variables.tf
  # --------------------------------------------------------------------------
  region = var.aws_region

  # --------------------------------------------------------------------------
  # PROFILE (Optional)
  # --------------------------------------------------------------------------
  # WHAT: AWS CLI profile to use for authentication
  # WHY: Allows using different credentials for different environments
  # DEFAULT: null = use default credential chain
  # CHAIN: Environment vars → Shared credentials → IAM role
  # --------------------------------------------------------------------------
  profile = var.aws_profile

  # --------------------------------------------------------------------------
  # DEFAULT TAGS
  # --------------------------------------------------------------------------
  # WHAT: Tags applied to ALL resources created by this provider
  # WHY: Consistent tagging for cost allocation, organization, compliance
  # NOTE: Resource-specific tags merge with (and override) these
  # --------------------------------------------------------------------------
  default_tags {
    tags = {
      # Project identifier
      Project = var.project_name

      # Environment (dev, staging, prod)
      Environment = var.environment

      # How this resource is managed
      ManagedBy = "Terraform"

      # Repository for reference
      Repository = "jenkins-infrastructure"
    }
  }
}

# ============================================================================
# ADDITIONAL PROVIDER CONFIGURATIONS
# ============================================================================

# TLS PROVIDER
# ------------
# Used for generating SSH key pairs
# No configuration needed - uses defaults
provider "tls" {}

# RANDOM PROVIDER
# ---------------
# Used for generating random values
# No configuration needed - uses defaults
provider "random" {}

# ============================================================================
# MULTI-REGION SETUP (Optional)
# ============================================================================
# Uncomment if you need resources in multiple regions
# ============================================================================

# provider "aws" {
#   alias  = "us_west_2"
#   region = "us-west-2"
#   
#   default_tags {
#     tags = {
#       Project     = var.project_name
#       Environment = var.environment
#       ManagedBy   = "Terraform"
#     }
#   }
# }

# ============================================================================
# AUTHENTICATION METHODS
# ============================================================================
#
# Terraform AWS provider supports multiple authentication methods:
#
# 1. ENVIRONMENT VARIABLES (Recommended for CI/CD):
#    export AWS_ACCESS_KEY_ID="your-access-key"
#    export AWS_SECRET_ACCESS_KEY="your-secret-key"
#    export AWS_REGION="us-east-1"
#
# 2. SHARED CREDENTIALS FILE (~/.aws/credentials):
#    [default]
#    aws_access_key_id = your-access-key
#    aws_secret_access_key = your-secret-key
#
# 3. AWS PROFILE:
#    provider "aws" {
#      profile = "my-profile"
#    }
#
# 4. IAM ROLE (Recommended for EC2/ECS):
#    - Attach IAM role to EC2 instance
#    - No credentials needed in code
#
# 5. ASSUME ROLE:
#    provider "aws" {
#      assume_role {
#        role_arn = "arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
#      }
#    }
#
# ============================================================================
