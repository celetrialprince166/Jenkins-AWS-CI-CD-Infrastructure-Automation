# ============================================================================
# EFS MODULE - Main Configuration
# ============================================================================
# PURPOSE: Create EFS file system for Jenkins persistent storage
# LOCATION: terraform/modules/efs/main.tf
# ============================================================================
#
# WHY EFS FOR JENKINS:
# - Persistence: Data survives instance termination
# - Shared: Multiple controllers can mount same filesystem
# - Managed: AWS handles backups, replication, availability
#
# WHAT'S STORED:
# - /var/lib/jenkins/jobs/     → Job configurations
# - /var/lib/jenkins/plugins/  → Installed plugins
# - /var/lib/jenkins/secrets/  → Credentials
# - /var/lib/jenkins/config.xml → Main configuration
#
# ============================================================================

# ============================================================================
# EFS FILE SYSTEM
# ============================================================================

resource "aws_efs_file_system" "jenkins" {
  # Creation token for idempotency
  creation_token = "${var.name_prefix}-jenkins-efs"

  # --------------------------------------------------------------------------
  # PERFORMANCE CONFIGURATION
  # --------------------------------------------------------------------------

  # Performance mode
  # - generalPurpose: Lower latency, good for most workloads
  # - maxIO: Higher throughput, higher latency (for parallel access)
  performance_mode = var.performance_mode

  # Throughput mode
  # - bursting: Scales with storage size
  # - provisioned: Fixed throughput (costs more)
  # - elastic: Automatically scales (recommended)
  throughput_mode = var.throughput_mode

  # --------------------------------------------------------------------------
  # ENCRYPTION
  # --------------------------------------------------------------------------

  # Encrypt data at rest
  # WHY: Security best practice, especially for Jenkins secrets
  encrypted = var.encrypted

  # --------------------------------------------------------------------------
  # LIFECYCLE POLICY
  # --------------------------------------------------------------------------

  # Move files to Infrequent Access after 30 days
  # WHY: Cost optimization for old build logs
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  # Move files back to Standard on access
  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  # --------------------------------------------------------------------------
  # TAGS
  # --------------------------------------------------------------------------

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-efs"
  })
}

# ============================================================================
# EFS MOUNT TARGETS
# ============================================================================
# One mount target per subnet (for high availability)

resource "aws_efs_mount_target" "jenkins" {
  count = length(var.subnet_ids)

  file_system_id  = aws_efs_file_system.jenkins.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [var.security_group_id]
}

# ============================================================================
# EFS ACCESS POINT (Optional)
# ============================================================================
# Provides application-specific entry point with POSIX permissions

resource "aws_efs_access_point" "jenkins" {
  file_system_id = aws_efs_file_system.jenkins.id

  # Root directory for this access point
  root_directory {
    path = "/jenkins"

    # Create directory if it doesn't exist
    creation_info {
      owner_gid   = 1000 # jenkins group
      owner_uid   = 1000 # jenkins user
      permissions = "0755"
    }
  }

  # POSIX user for all operations through this access point
  posix_user {
    gid = 1000 # jenkins group
    uid = 1000 # jenkins user
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-ap"
  })
}

# ============================================================================
# EFS BACKUP POLICY
# ============================================================================
# Enable automatic backups

resource "aws_efs_backup_policy" "jenkins" {
  file_system_id = aws_efs_file_system.jenkins.id

  backup_policy {
    status = "ENABLED"
  }
}
