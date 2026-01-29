# ============================================================================
# EFS MODULE - Outputs
# ============================================================================
# LOCATION: terraform/modules/efs/outputs.tf
# ============================================================================

output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.jenkins.id
}

output "efs_arn" {
  description = "ARN of the EFS file system"
  value       = aws_efs_file_system.jenkins.arn
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.jenkins.dns_name
}

output "mount_target_ids" {
  description = "IDs of the EFS mount targets"
  value       = aws_efs_mount_target.jenkins[*].id
}

output "mount_target_dns_names" {
  description = "DNS names of the EFS mount targets"
  value       = aws_efs_mount_target.jenkins[*].dns_name
}

output "access_point_id" {
  description = "ID of the EFS access point"
  value       = aws_efs_access_point.jenkins.id
}

output "access_point_arn" {
  description = "ARN of the EFS access point"
  value       = aws_efs_access_point.jenkins.arn
}
