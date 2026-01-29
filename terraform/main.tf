# ============================================================================
# TERRAFORM ROOT MODULE - Main Configuration
# ============================================================================
# PURPOSE: Wire together all modules to create Jenkins infrastructure
# LOCATION: terraform/main.tf
# ============================================================================

# ============================================================================
# VPC MODULE
# ============================================================================
# Creates: VPC, Subnets, Internet Gateway, NAT Gateway, Route Tables

module "vpc" {
  source = "./modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = local.common_tags
}

# ============================================================================
# SECURITY GROUPS MODULE
# ============================================================================
# Creates: ALB SG, Controller SG, Agent SG, EFS SG

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  jenkins_http_port  = var.jenkins_http_port
  jenkins_agent_port = var.jenkins_agent_port
  tags               = local.common_tags
}

# ============================================================================
# EFS MODULE
# ============================================================================
# Creates: EFS File System, Mount Targets, Access Point

module "efs" {
  source = "./modules/efs"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.security_groups.efs_security_group_id
  performance_mode  = var.efs_performance_mode
  throughput_mode   = var.efs_throughput_mode
  encrypted         = var.efs_encrypted
  tags              = local.common_tags
}

# ============================================================================
# IAM MODULE
# ============================================================================
# Creates: Controller Role, Agent Role, Instance Profiles

module "iam" {
  source = "./modules/iam"

  name_prefix              = local.name_prefix
  efs_arn                  = module.efs.efs_arn
  agent_ssh_key_secret_arn = aws_secretsmanager_secret.jenkins_agent_key.arn
  tags                     = local.common_tags
}

# ============================================================================
# ALB MODULE
# ============================================================================
# Creates: Application Load Balancer, Target Group, Listeners

module "alb" {
  source = "./modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_security_group_id
  jenkins_http_port = var.jenkins_http_port
  health_check_path = var.health_check_path
  certificate_arn   = var.alb_certificate_arn
  internal          = var.alb_internal
  tags              = local.common_tags
}

# ============================================================================
# ASG MODULE
# ============================================================================
# Creates: Launch Templates, Auto Scaling Groups

module "asg" {
  source = "./modules/asg"

  name_prefix = local.name_prefix

  # Controller configuration
  controller_ami_id                = var.controller_ami_id
  controller_instance_type         = var.controller_instance_type
  controller_security_group_id     = module.security_groups.controller_security_group_id
  controller_instance_profile_name = module.iam.controller_instance_profile_name
  controller_min_size              = var.controller_min_size
  controller_max_size              = var.controller_max_size
  controller_desired_size          = var.controller_desired_size
  controller_volume_size           = var.controller_volume_size
  controller_cpu_target            = var.controller_cpu_target

  # Agent configuration
  agent_ami_id                = var.agent_ami_id
  agent_instance_type         = var.agent_instance_type
  agent_security_group_id     = module.security_groups.agent_security_group_id
  agent_instance_profile_name = module.iam.agent_instance_profile_name
  agent_min_size              = var.agent_min_size
  agent_max_size              = var.agent_max_size
  agent_desired_size          = var.agent_desired_size
  agent_volume_size           = var.agent_volume_size
  agent_cpu_target            = var.agent_cpu_target

  # Common configuration
  subnet_ids       = module.vpc.private_subnet_ids
  target_group_arn = module.alb.target_group_arn
  key_name         = var.create_ssh_key ? aws_key_pair.jenkins[0].key_name : var.key_name

  # User data scripts
  controller_user_data = templatefile("${path.module}/templates/controller-user-data.sh", {
    efs_dns_name            = module.efs.efs_dns_name
    jenkins_home            = local.jenkins_home
    jenkins_user            = local.jenkins_user
    aws_region              = var.aws_region
    agent_ssh_key_secret_name = aws_secretsmanager_secret.jenkins_agent_key.name
  })

  agent_user_data = templatefile("${path.module}/templates/agent-user-data.sh", {
    jenkins_user          = local.jenkins_user
    controller_public_key = tls_private_key.jenkins_agent.public_key_openssh
  })

  tags = local.common_tags

  # Ensure EFS is ready before launching instances
  depends_on = [module.efs]
}

# ============================================================================
# SSH KEY PAIR (Optional - for bastion/debugging access)
# ============================================================================
# Creates SSH key pair for instance access

resource "tls_private_key" "jenkins" {
  count     = var.create_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins" {
  count      = var.create_ssh_key ? 1 : 0
  key_name   = "${local.name_prefix}-key"
  public_key = tls_private_key.jenkins[0].public_key_openssh

  tags = local.common_tags
}

# Store private key in Secrets Manager
resource "aws_secretsmanager_secret" "ssh_key" {
  count = var.create_ssh_key ? 1 : 0
  name  = "${local.name_prefix}-ssh-private-key"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "ssh_key" {
  count         = var.create_ssh_key ? 1 : 0
  secret_id     = aws_secretsmanager_secret.ssh_key[0].id
  secret_string = tls_private_key.jenkins[0].private_key_pem
}

# ============================================================================
# SSH KEY PAIR FOR CONTROLLER-AGENT COMMUNICATION
# ============================================================================
# PURPOSE: Controller uses private key to SSH into agents
# FLOW: Controller (private key) --> SSH --> Agent (public key)
# ============================================================================

resource "tls_private_key" "jenkins_agent" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store private key in Secrets Manager (controller retrieves this)
resource "aws_secretsmanager_secret" "jenkins_agent_key" {
  name = "${local.name_prefix}-agent-ssh-key"

  tags = merge(local.common_tags, {
    Purpose = "Controller-Agent SSH Communication"
  })
}

resource "aws_secretsmanager_secret_version" "jenkins_agent_key" {
  secret_id     = aws_secretsmanager_secret.jenkins_agent_key.id
  secret_string = tls_private_key.jenkins_agent.private_key_pem
}
