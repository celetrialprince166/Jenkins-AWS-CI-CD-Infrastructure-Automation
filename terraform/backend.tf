# ==========================================================================
# Add this to terraform/backend.tf
# ==========================================================================

terraform {
  backend "s3" {
    bucket       = "jenkins-terraform-state-904570587823"  
    key          = "jenkins-infrastructure/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true  # S3 native locking (Terraform 1.10+)
  }
}
