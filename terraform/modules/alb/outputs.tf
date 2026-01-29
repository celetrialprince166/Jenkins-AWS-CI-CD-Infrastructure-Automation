# ============================================================================
# ALB MODULE - Outputs
# ============================================================================
output "alb_id" {
  description = "ID of the ALB"
  value       = aws_lb.jenkins.id
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.jenkins.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.jenkins.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = aws_lb.jenkins.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.jenkins.arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.jenkins.name
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "http://${aws_lb.jenkins.dns_name}"
}
