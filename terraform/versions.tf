# ============================================================================
# TERRAFORM VERSION CONSTRAINTS
# ============================================================================
# PURPOSE: Lock Terraform and provider versions for consistency
# LOCATION: terraform/versions.tf
# WHY: Ensures everyone uses the same versions, preventing "works on my machine"
# ============================================================================

terraform {
  # --------------------------------------------------------------------------
  # TERRAFORM VERSION
  # --------------------------------------------------------------------------
  # WHAT: Minimum Terraform version required
  # WHY: 1.10+ required for S3 native state locking (use_lockfile)
  # CHECK: https://releases.hashicorp.com/terraform/
  # --------------------------------------------------------------------------
  required_version = ">= 1.10.0"

  # --------------------------------------------------------------------------
  # REQUIRED PROVIDERS
  # --------------------------------------------------------------------------
  # WHAT: External plugins Terraform needs to manage resources
  # WHY: Providers are versioned separately from Terraform core
  # --------------------------------------------------------------------------
  required_providers {
    # AWS PROVIDER
    # ------------
    # WHAT: Manages AWS resources (EC2, VPC, EFS, etc.)
    # SOURCE: Official HashiCorp AWS provider
    # VERSION: ~> 5.0 means >= 5.0.0 and < 6.0.0 (allows minor updates)
    # DOCS: https://registry.terraform.io/providers/hashicorp/aws/latest
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # TLS PROVIDER
    # ------------
    # WHAT: Generates TLS keys and certificates
    # WHY: We use it to generate SSH key pairs for controller-agent communication
    # DOCS: https://registry.terraform.io/providers/hashicorp/tls/latest
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    # RANDOM PROVIDER
    # ---------------
    # WHAT: Generates random values
    # WHY: Used for unique naming, passwords, etc.
    # DOCS: https://registry.terraform.io/providers/hashicorp/random/latest
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # --------------------------------------------------------------------------
  # BACKEND CONFIGURATION (Optional)
  # --------------------------------------------------------------------------
  # WHAT: Where Terraform stores state
  # DEFAULT: Local file (terraform.tfstate)
  # PRODUCTION: Use S3 backend with DynamoDB locking
  # --------------------------------------------------------------------------
  # Uncomment for remote state (recommended for teams):
  #
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "jenkins-infrastructure/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# ============================================================================
# VERSION PINNING STRATEGY
# ============================================================================
#
# We use "~>" (pessimistic constraint) for providers:
# - ~> 5.0 means >= 5.0.0 AND < 6.0.0
# - Allows patch and minor updates (bug fixes, new features)
# - Blocks major updates (potential breaking changes)
#
# For production, consider pinning exact versions:
# - version = "5.31.0"
# - More predictable, but requires manual updates
#
# ============================================================================
