# ============================================================================
# ASG MODULE - Main Configuration
# ============================================================================
# PURPOSE: Create Launch Templates and Auto Scaling Groups
# LOCATION: terraform/modules/asg/main.tf
# ============================================================================

# ============================================================================
# CONTROLLER LAUNCH TEMPLATE
# ============================================================================

resource "aws_launch_template" "controller" {
  name_prefix   = "${var.name_prefix}-controller-"
  image_id      = var.controller_ami_id
  instance_type = var.controller_instance_type

  # IAM instance profile
  iam_instance_profile {
    name = var.controller_instance_profile_name
  }

  # Network configuration
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.controller_security_group_id]
    delete_on_termination       = true
  }

  # Storage configuration
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.controller_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # SSH key (optional)
  key_name = var.key_name

  # User data script
  user_data = base64encode(var.controller_user_data)

  # Metadata options
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2
    http_put_response_hop_limit = 1
  }

  # Monitoring
  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name     = "${var.name_prefix}-controller"
      NodeType = "controller"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-controller-volume"
    })
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# CONTROLLER AUTO SCALING GROUP
# ============================================================================

resource "aws_autoscaling_group" "controller" {
  name                = "${var.name_prefix}-controller-asg"
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [var.target_group_arn]

  min_size         = var.controller_min_size
  max_size         = var.controller_max_size
  desired_capacity = var.controller_desired_size

  # Health check configuration
  health_check_type         = "ELB"
  health_check_grace_period = 600  # 10 minutes for Jenkins to start

  # Launch template
  launch_template {
    id      = aws_launch_template.controller.id
    version = "$Latest"
  }

  # Instance refresh for updates
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  # Tags
  dynamic "tag" {
    for_each = merge(var.tags, {
      Name     = "${var.name_prefix}-controller"
      NodeType = "controller"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# AGENT LAUNCH TEMPLATE
# ============================================================================

resource "aws_launch_template" "agent" {
  name_prefix   = "${var.name_prefix}-agent-"
  image_id      = var.agent_ami_id
  instance_type = var.agent_instance_type

  iam_instance_profile {
    name = var.agent_instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.agent_security_group_id]
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.agent_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  key_name  = var.key_name
  user_data = base64encode(var.agent_user_data)

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name      = "${var.name_prefix}-agent"
      NodeType  = "agent"
      ManagedBy = "Jenkins"  # For EC2 plugin
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-agent-volume"
    })
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# AGENT AUTO SCALING GROUP
# ============================================================================

resource "aws_autoscaling_group" "agent" {
  name                = "${var.name_prefix}-agent-asg"
  vpc_zone_identifier = var.subnet_ids

  min_size         = var.agent_min_size
  max_size         = var.agent_max_size
  desired_capacity = var.agent_desired_size

  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.agent.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(var.tags, {
      Name      = "${var.name_prefix}-agent"
      NodeType  = "agent"
      ManagedBy = "Jenkins"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# SCALING POLICIES - For Testing Auto Scaling
# ============================================================================
# These policies allow you to manually trigger scale-out/scale-in events
# to verify ASG behavior without waiting for CloudWatch alarms.
#
# TEST COMMANDS:
#   Scale Out: aws autoscaling execute-policy --policy-name <scale-out-policy> --auto-scaling-group-name <asg-name>
#   Scale In:  aws autoscaling execute-policy --policy-name <scale-in-policy> --auto-scaling-group-name <asg-name>
# ============================================================================

# --------------------------------------------------------------------------
# CONTROLLER SCALING POLICIES
# --------------------------------------------------------------------------

resource "aws_autoscaling_policy" "controller_scale_out" {
  name                   = "${var.name_prefix}-controller-scale-out"
  autoscaling_group_name = aws_autoscaling_group.controller.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300  # 5 minutes between scaling actions

  # Policy type: Simple scaling (good for manual testing)
  policy_type = "SimpleScaling"
}

resource "aws_autoscaling_policy" "controller_scale_in" {
  name                   = "${var.name_prefix}-controller-scale-in"
  autoscaling_group_name = aws_autoscaling_group.controller.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300

  policy_type = "SimpleScaling"
}

# --------------------------------------------------------------------------
# AGENT SCALING POLICIES
# --------------------------------------------------------------------------

resource "aws_autoscaling_policy" "agent_scale_out" {
  name                   = "${var.name_prefix}-agent-scale-out"
  autoscaling_group_name = aws_autoscaling_group.agent.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120  # 2 minutes (agents can scale faster)

  policy_type = "SimpleScaling"
}

resource "aws_autoscaling_policy" "agent_scale_in" {
  name                   = "${var.name_prefix}-agent-scale-in"
  autoscaling_group_name = aws_autoscaling_group.agent.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120

  policy_type = "SimpleScaling"
}

# ============================================================================
# TARGET TRACKING SCALING POLICIES - Automatic Production Scaling
# ============================================================================
# These policies automatically scale based on metrics. AWS handles the math
# of how many instances to add/remove to reach the target.
#
# HOW IT WORKS:
#   1. You set a target (e.g., 50% CPU utilization)
#   2. AWS continuously monitors the metric
#   3. If metric > target → Scale OUT (add instances)
#   4. If metric < target → Scale IN (remove instances)
#
# WHY TARGET TRACKING?
#   - Simpler than step scaling (no need to define multiple thresholds)
#   - AWS optimizes scaling to minimize cost while meeting target
#   - Handles both scale-out and scale-in automatically
# ============================================================================

# --------------------------------------------------------------------------
# AGENT TARGET TRACKING - CPU Based (Primary)
# --------------------------------------------------------------------------
# Agents do the heavy lifting (builds), so CPU is the best metric.
# Target: 50% CPU - leaves headroom for build spikes

resource "aws_autoscaling_policy" "agent_cpu_target_tracking" {
  name                   = "${var.name_prefix}-agent-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.agent.name
  policy_type            = "TargetTrackingScaling"

  # Cooldowns are estimated - AWS manages actual timing for target tracking
  estimated_instance_warmup = 120  # 2 minutes for agent to be ready

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.agent_cpu_target  # Default: 50%

    # Allow scale-in (set to true to disable scale-in)
    disable_scale_in = false
  }
}

# --------------------------------------------------------------------------
# CONTROLLER TARGET TRACKING - CPU Based
# --------------------------------------------------------------------------
# Controllers are less CPU-intensive but still need scaling for HA.
# Target: 60% CPU - controllers are more stable workload

resource "aws_autoscaling_policy" "controller_cpu_target_tracking" {
  name                   = "${var.name_prefix}-controller-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.controller.name
  policy_type            = "TargetTrackingScaling"

  # Controllers need more time to initialize (Jenkins startup)
  estimated_instance_warmup = 600  # 10 minutes for Jenkins to start

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.controller_cpu_target  # Default: 60%

    # Allow scale-in (set to true to disable scale-in)
    disable_scale_in = false
  }
}
