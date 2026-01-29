# ============================================================================
# LOCAL VALUES
# ============================================================================
# PURPOSE: Computed values and common expressions
# LOCATION: terraform/locals.tf
# WHY: Avoid repetition, centralize naming conventions
# ============================================================================

locals {
  # --------------------------------------------------------------------------
  # NAMING
  # --------------------------------------------------------------------------
  # Consistent naming prefix for all resources
  # FORMAT: {project}-{environment}
  # EXAMPLE: jenkins-dev, jenkins-prod
  # --------------------------------------------------------------------------
  name_prefix = "${var.project_name}-${var.environment}"

  # --------------------------------------------------------------------------
  # COMMON TAGS
  # --------------------------------------------------------------------------
  # Tags applied to resources (in addition to provider default_tags)
  # --------------------------------------------------------------------------
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )

  # --------------------------------------------------------------------------
  # AVAILABILITY ZONES
  # --------------------------------------------------------------------------
  # Number of AZs we're using
  # --------------------------------------------------------------------------
  az_count = length(var.availability_zones)

  # --------------------------------------------------------------------------
  # JENKINS CONFIGURATION
  # --------------------------------------------------------------------------
  # Values used by multiple modules
  # --------------------------------------------------------------------------
  jenkins_home       = "/var/lib/jenkins"
  jenkins_user       = "jenkins"
  jenkins_http_port  = var.jenkins_http_port
  jenkins_agent_port = var.jenkins_agent_port

  # --------------------------------------------------------------------------
  # EFS DNS NAME FORMAT
  # --------------------------------------------------------------------------
  # EFS DNS name follows this pattern
  # Used in user_data scripts
  # --------------------------------------------------------------------------
  # Note: Actual value comes from EFS module output
  # This is just the format for reference
  efs_dns_format = "fs-XXXXXXXX.efs.${var.aws_region}.amazonaws.com"

  # --------------------------------------------------------------------------
  # USER DATA SCRIPTS
  # --------------------------------------------------------------------------
  # User data scripts are now in separate template files:
  # - templates/controller-user-data.sh
  # - templates/agent-user-data.sh
  #
  # They are loaded via templatefile() in main.tf
  # --------------------------------------------------------------------------
}
