# ============================================================================
# SECURITY GROUPS MODULE - Outputs
# ============================================================================
# LOCATION: terraform/modules/security-groups/outputs.tf
# ============================================================================

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "controller_security_group_id" {
  description = "ID of the Controller security group"
  value       = aws_security_group.controller.id
}

output "agent_security_group_id" {
  description = "ID of the Agent security group"
  value       = aws_security_group.agent.id
}

output "efs_security_group_id" {
  description = "ID of the EFS security group"
  value       = aws_security_group.efs.id
}

# Export all security group IDs as a map
output "security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    alb        = aws_security_group.alb.id
    controller = aws_security_group.controller.id
    agent      = aws_security_group.agent.id
    efs        = aws_security_group.efs.id
  }
}
