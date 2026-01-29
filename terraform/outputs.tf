# ============================================================================
# TERRAFORM OUTPUTS
# ============================================================================
# PURPOSE: Export useful values after deployment
# LOCATION: terraform/outputs.tf
# ============================================================================

# ============================================================================
# JENKINS ACCESS
# ============================================================================

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = module.alb.jenkins_url
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

# ============================================================================
# VPC INFORMATION
# ============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

# ============================================================================
# EFS INFORMATION
# ============================================================================

output "efs_id" {
  description = "ID of the EFS file system"
  value       = module.efs.efs_id
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = module.efs.efs_dns_name
}

# ============================================================================
# SECURITY GROUPS
# ============================================================================

output "security_group_ids" {
  description = "Map of security group IDs"
  value       = module.security_groups.security_group_ids
}

# ============================================================================
# AUTO SCALING GROUPS
# ============================================================================

output "controller_asg_name" {
  description = "Name of the controller Auto Scaling Group"
  value       = module.asg.controller_asg_name
}

output "agent_asg_name" {
  description = "Name of the agent Auto Scaling Group"
  value       = module.asg.agent_asg_name
}

# ============================================================================
# SCALING POLICIES (for testing)
# ============================================================================

output "controller_scale_out_policy_arn" {
  description = "ARN of controller scale-out policy"
  value       = module.asg.controller_scale_out_policy_arn
}

output "controller_scale_in_policy_arn" {
  description = "ARN of controller scale-in policy"
  value       = module.asg.controller_scale_in_policy_arn
}

output "agent_scale_out_policy_arn" {
  description = "ARN of agent scale-out policy"
  value       = module.asg.agent_scale_out_policy_arn
}

output "agent_scale_in_policy_arn" {
  description = "ARN of agent scale-in policy"
  value       = module.asg.agent_scale_in_policy_arn
}

# ============================================================================
# SSH KEY (if created)
# ============================================================================

output "ssh_key_name" {
  description = "Name of the SSH key pair"
  value       = var.create_ssh_key ? aws_key_pair.jenkins[0].key_name : var.key_name
}

output "ssh_private_key_secret_arn" {
  description = "ARN of the secret containing SSH private key"
  value       = var.create_ssh_key ? aws_secretsmanager_secret.ssh_key[0].arn : null
  sensitive   = true
}

# ============================================================================
# CONTROLLER-AGENT SSH KEY
# ============================================================================

output "agent_ssh_key_secret_arn" {
  description = "ARN of the secret containing the controller-agent SSH private key"
  value       = aws_secretsmanager_secret.jenkins_agent_key.arn
  sensitive   = true
}

output "agent_ssh_key_secret_name" {
  description = "Name of the secret containing the controller-agent SSH private key"
  value       = aws_secretsmanager_secret.jenkins_agent_key.name
}

# ============================================================================
# SUMMARY
# ============================================================================

output "deployment_summary" {
  description = "Summary of the deployment"
  value       = <<-EOT
    
    ============================================
    Jenkins Infrastructure Deployed Successfully!
    ============================================
    
    Jenkins URL: ${module.alb.jenkins_url}
    
    VPC ID: ${module.vpc.vpc_id}
    EFS ID: ${module.efs.efs_id}
    
    Controller ASG: ${module.asg.controller_asg_name}
    Agent ASG: ${module.asg.agent_asg_name}
    
    Next Steps:
    1. Wait 5-10 minutes for Jenkins to start
    2. Access Jenkins at the URL above
    3. Get initial admin password from Jenkins logs
    4. Configure Jenkins and add agents
    
    ============================================
  EOT
}
