# ============================================================================
# ASG MODULE - Outputs
# ============================================================================
output "controller_asg_name" {
  description = "Name of the controller ASG"
  value       = aws_autoscaling_group.controller.name
}

output "controller_asg_arn" {
  description = "ARN of the controller ASG"
  value       = aws_autoscaling_group.controller.arn
}

output "controller_launch_template_id" {
  description = "ID of the controller launch template"
  value       = aws_launch_template.controller.id
}

output "agent_asg_name" {
  description = "Name of the agent ASG"
  value       = aws_autoscaling_group.agent.name
}

output "agent_asg_arn" {
  description = "ARN of the agent ASG"
  value       = aws_autoscaling_group.agent.arn
}

output "agent_launch_template_id" {
  description = "ID of the agent launch template"
  value       = aws_launch_template.agent.id
}

# ============================================================================
# SCALING POLICY OUTPUTS - Simple Scaling (Manual Testing)
# ============================================================================

output "controller_scale_out_policy_arn" {
  description = "ARN of controller scale-out policy (manual trigger)"
  value       = aws_autoscaling_policy.controller_scale_out.arn
}

output "controller_scale_in_policy_arn" {
  description = "ARN of controller scale-in policy (manual trigger)"
  value       = aws_autoscaling_policy.controller_scale_in.arn
}

output "agent_scale_out_policy_arn" {
  description = "ARN of agent scale-out policy (manual trigger)"
  value       = aws_autoscaling_policy.agent_scale_out.arn
}

output "agent_scale_in_policy_arn" {
  description = "ARN of agent scale-in policy (manual trigger)"
  value       = aws_autoscaling_policy.agent_scale_in.arn
}

# ============================================================================
# TARGET TRACKING POLICY OUTPUTS - Automatic Scaling
# ============================================================================

output "agent_cpu_target_tracking_policy_arn" {
  description = "ARN of agent CPU target tracking policy (automatic scaling)"
  value       = aws_autoscaling_policy.agent_cpu_target_tracking.arn
}

output "controller_cpu_target_tracking_policy_arn" {
  description = "ARN of controller CPU target tracking policy (automatic scaling)"
  value       = aws_autoscaling_policy.controller_cpu_target_tracking.arn
}
