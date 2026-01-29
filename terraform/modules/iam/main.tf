# ============================================================================
# IAM MODULE - Main Configuration
# ============================================================================
# PURPOSE: Create IAM roles and policies for Jenkins instances
# LOCATION: terraform/modules/iam/main.tf
# ============================================================================
#
# PRINCIPLE OF LEAST PRIVILEGE:
# Each role has only the permissions it needs, nothing more.
#
# CONTROLLER ROLE:
# - EFS access (mount filesystem)
# - EC2 describe (for EC2 plugin to launch agents)
# - SSM (for Session Manager access)
# - CloudWatch (for logging)
#
# AGENT ROLE:
# - ECR access (pull Docker images)
# - S3 access (artifacts)
# - CloudWatch (for logging)
#
# ============================================================================

# ============================================================================
# CONTROLLER IAM ROLE
# ============================================================================

resource "aws_iam_role" "controller" {
  name = "${var.name_prefix}-controller-role"

  # Trust policy - who can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-controller-role"
  })
}

# Controller instance profile (required for EC2)
resource "aws_iam_instance_profile" "controller" {
  name = "${var.name_prefix}-controller-profile"
  role = aws_iam_role.controller.name

  tags = var.tags
}

# --------------------------------------------------------------------------
# CONTROLLER POLICIES
# --------------------------------------------------------------------------

# EFS Access Policy
resource "aws_iam_role_policy" "controller_efs" {
  name = "${var.name_prefix}-controller-efs-policy"
  role = aws_iam_role.controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EFSAccess"
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess",
          "elasticfilesystem:DescribeMountTargets",
          "elasticfilesystem:DescribeFileSystems"
        ]
        Resource = var.efs_arn
      }
    ]
  })
}

# EC2 Access Policy (for EC2 plugin to manage agents)
resource "aws_iam_role_policy" "controller_ec2" {
  name = "${var.name_prefix}-controller-ec2-policy"
  role = aws_iam_role.controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2DescribeInstances"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2ManageInstances"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:CreateTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/ManagedBy" = "Jenkins"
          }
        }
      },
      {
        Sid    = "EC2RunInstances"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances"
        ]
        Resource = [
          "arn:aws:ec2:*:*:instance/*",
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:network-interface/*",
          "arn:aws:ec2:*:*:security-group/*",
          "arn:aws:ec2:*:*:subnet/*",
          "arn:aws:ec2:*:*:image/*",
          "arn:aws:ec2:*:*:key-pair/*"
        ]
      },
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.agent.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Secrets Manager Access Policy (for retrieving agent SSH private key)
resource "aws_iam_role_policy" "controller_secrets" {
  name = "${var.name_prefix}-controller-secrets-policy"
  role = aws_iam_role.controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.agent_ssh_key_secret_arn
      }
    ]
  })
}

# CloudWatch Policy (for logging)
resource "aws_iam_role_policy_attachment" "controller_cloudwatch" {
  role       = aws_iam_role.controller.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# SSM Policy (for Session Manager access - no SSH key needed!)
resource "aws_iam_role_policy_attachment" "controller_ssm" {
  role       = aws_iam_role.controller.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ============================================================================
# AGENT IAM ROLE
# ============================================================================

resource "aws_iam_role" "agent" {
  name = "${var.name_prefix}-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-agent-role"
  })
}

# Agent instance profile
resource "aws_iam_instance_profile" "agent" {
  name = "${var.name_prefix}-agent-profile"
  role = aws_iam_role.agent.name

  tags = var.tags
}

# --------------------------------------------------------------------------
# AGENT POLICIES
# --------------------------------------------------------------------------

# ECR Access Policy (for pulling Docker images)
resource "aws_iam_role_policy" "agent_ecr" {
  name = "${var.name_prefix}-agent-ecr-policy"
  role = aws_iam_role.agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "*"
      }
    ]
  })
}

# S3 Access Policy (for artifacts)
resource "aws_iam_role_policy" "agent_s3" {
  name = "${var.name_prefix}-agent-s3-policy"
  role = aws_iam_role.agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.name_prefix}-*",
          "arn:aws:s3:::${var.name_prefix}-*/*"
        ]
      }
    ]
  })
}

# CloudWatch Policy
resource "aws_iam_role_policy_attachment" "agent_cloudwatch" {
  role       = aws_iam_role.agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# SSM Policy (for Session Manager access - no SSH key needed!)
resource "aws_iam_role_policy_attachment" "agent_ssm" {
  role       = aws_iam_role.agent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
