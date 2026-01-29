# ============================================================================
# ALB MODULE - Main Configuration
# ============================================================================
# PURPOSE: Create Application Load Balancer for Jenkins
# LOCATION: terraform/modules/alb/main.tf
# ============================================================================

# ============================================================================
# APPLICATION LOAD BALANCER
# ============================================================================

resource "aws_lb" "jenkins" {
  name               = "${var.name_prefix}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids

  # Enable deletion protection in production
  enable_deletion_protection = false

  # Access logs (optional)
  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.bucket
  #   prefix  = "jenkins-alb"
  #   enabled = true
  # }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb"
  })
}

# ============================================================================
# TARGET GROUP
# ============================================================================

resource "aws_lb_target_group" "jenkins" {
  name     = "${var.name_prefix}-tg"
  port     = var.jenkins_http_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 30
    interval            = 60
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200,403" # 403 is OK (login page)
  }

  # Stickiness - keep user on same instance
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400 # 24 hours
    enabled         = true
  }

  # Deregistration delay
  deregistration_delay = 300

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tg"
  })
}

# ============================================================================
# LISTENERS
# ============================================================================

# HTTP Listener (redirect to HTTPS if certificate provided)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.certificate_arn != null ? "redirect" : "forward"

    # Redirect to HTTPS if certificate is provided
    dynamic "redirect" {
      for_each = var.certificate_arn != null ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    # Forward to target group if no certificate
    target_group_arn = var.certificate_arn == null ? aws_lb_target_group.jenkins.arn : null
  }
}

# HTTPS Listener (only if certificate provided)
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.jenkins.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}
