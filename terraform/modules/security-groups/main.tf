# ============================================================================
# SECURITY GROUPS MODULE - Main Configuration
# ============================================================================
# PURPOSE: Define firewall rules for all components
# LOCATION: terraform/modules/security-groups/main.tf
# ============================================================================
#
# SECURITY GROUP ARCHITECTURE:
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │                         TRAFFIC FLOW                                    │
# ├─────────────────────────────────────────────────────────────────────────┤
# │                                                                         │
# │  INTERNET                                                               │
# │      │                                                                  │
# │      │ HTTPS (443) / HTTP (80)                                         │
# │      ▼                                                                  │
# │  ┌─────────────────┐                                                   │
# │  │   ALB SG        │                                                   │
# │  │   (sg-alb)      │                                                   │
# │  └────────┬────────┘                                                   │
# │           │                                                             │
# │           │ HTTP (8080)                                                │
# │           ▼                                                             │
# │  ┌─────────────────┐         SSH (22)        ┌─────────────────┐       │
# │  │  CONTROLLER SG  │ ──────────────────────► │    AGENT SG     │       │
# │  │  (sg-controller)│                         │   (sg-agent)    │       │
# │  └────────┬────────┘ ◄────────────────────── └─────────────────┘       │
# │           │              JNLP (50000)                                   │
# │           │                                                             │
# │           │ NFS(2049)                                                │
# │           ▼                                                             │
# │  ┌─────────────────┐                                                   │
# │  │    EFS SG       │                                                   │
# │  │   (sg-efs)      │                                                   │
# │  └─────────────────┘                                                   │
# │                                                                         │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ============================================================================

# ============================================================================
# ALB SECURITY GROUP
# ============================================================================
# Allows inbound HTTP/HTTPS from internet

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # --------------------------------------------------------------------------
  # INBOUND RULES
  # --------------------------------------------------------------------------

  # HTTP from anywhere (redirects to HTTPS)
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS from anywhere
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --------------------------------------------------------------------------
  # OUTBOUND RULES
  # --------------------------------------------------------------------------

  # Allow all outbound (to reach controllers)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

# ============================================================================
# CONTROLLER SECURITY GROUP
# ============================================================================
# Allows traffic from ALB and agents

resource "aws_security_group" "controller" {
  name        = "${var.name_prefix}-controller-sg"
  description = "Security group for Jenkins Controller"
  vpc_id      = var.vpc_id

  # --------------------------------------------------------------------------
  # INBOUND RULES
  # --------------------------------------------------------------------------

  # Jenkins HTTP from ALB only
  ingress {
    description     = "Jenkins HTTP from ALB"
    from_port       = var.jenkins_http_port
    to_port         = var.jenkins_http_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # JNLP from agents (for agent connections)
  # NOTE: This rule references agent SG, created below
  # We'll add this rule after agent SG is created

  # SSH from within VPC (for bastion/debugging)
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # --------------------------------------------------------------------------
  # OUTBOUND RULES
  # --------------------------------------------------------------------------

  # All outbound (for package downloads, agent communication, etc.)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-controller-sg"
  })
}

# ============================================================================
# AGENT SECURITY GROUP
# ============================================================================
# Allows SSH from controller

resource "aws_security_group" "agent" {
  name        = "${var.name_prefix}-agent-sg"
  description = "Security group for Jenkins Agents"
  vpc_id      = var.vpc_id

  # --------------------------------------------------------------------------
  # INBOUND RULES
  # --------------------------------------------------------------------------

  # SSH from controller (for launching agent process)
  ingress {
    description     = "SSH from Controller"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.controller.id]
  }

  # SSH from within VPC (for debugging)
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # --------------------------------------------------------------------------
  # OUTBOUND RULES
  # --------------------------------------------------------------------------

  # All outbound (for package downloads, git clone, docker pull, etc.)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-agent-sg"
  })
}

# ============================================================================
# CONTROLLER SECURITY GROUP - ADDITIONAL RULES
# ============================================================================
# Add rules that reference agent SG (created after agent SG exists)

# JNLP from agents
resource "aws_security_group_rule" "controller_jnlp_from_agents" {
  type                     = "ingress"
  description              = "JNLP from Agents"
  from_port                = var.jenkins_agent_port
  to_port                  = var.jenkins_agent_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.controller.id
  source_security_group_id = aws_security_group.agent.id
}

# ============================================================================
# EFS SECURITY GROUP
# ============================================================================
# Allows NFS from controllers only

resource "aws_security_group" "efs" {
  name        = "${var.name_prefix}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = var.vpc_id

  # --------------------------------------------------------------------------
  # INBOUND RULES
  # --------------------------------------------------------------------------

  # NFS from controllers only
  ingress {
    description     = "NFS from Controllers"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.controller.id]
  }

  # --------------------------------------------------------------------------
  # OUTBOUND RULES
  # --------------------------------------------------------------------------

  # NFS responses to controllers
  egress {
    description     = "NFS to Controllers"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.controller.id]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-efs-sg"
  })
}
