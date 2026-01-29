# ============================================================================
# IAM MODULE - Outputs
# ============================================================================
# LOCATION: terraform/modules/iam/outputs.tf
# ============================================================================

output "controller_role_arn" {
  description = "ARN of the controller IAM role"
  value       = aws_iam_role.controller.arn
}

output "controller_role_name" {
  description = "Name of the controller IAM role"
  value       = aws_iam_role.controller.name
}

output "controller_instance_profile_arn" {
  description = "ARN of the controller instance profile"
  value       = aws_iam_instance_profile.controller.arn
}

output "controller_instance_profile_name" {
  description = "Name of the controller instance profile"
  value       = aws_iam_instance_profile.controller.name
}

output "agent_role_arn" {
  description = "ARN of the agent IAM role"
  value       = aws_iam_role.agent.arn
}

output "agent_role_name" {
  description = "Name of the agent IAM role"
  value       = aws_iam_role.agent.name
}

output "agent_instance_profile_arn" {
  description = "ARN of the agent instance profile"
  value       = aws_iam_instance_profile.agent.arn
}

output "agent_instance_profile_name" {
  description = "Name of the agent instance profile"
  value       = aws_iam_instance_profile.agent.name
}
