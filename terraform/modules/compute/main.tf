locals {
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    node_package   = var.node_package
    release_bucket = var.release_bucket
    app_version    = var.app_version
    region         = var.region
    app_port       = var.app_port
    db_secret_arn  = var.db_secret_arn
    app_bucket     = var.app_bucket
    color          = var.color
  })
}

resource "aws_launch_template" "this" {
  name_prefix = "${var.name}-${var.color}-"
  # Resolved at launch time -> always the current Amazon Linux 2023 AMI, no template drift.
  image_id      = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type = var.instance_type
  user_data     = base64encode(local.user_data)

  iam_instance_profile { name = var.instance_profile_name }
  vpc_security_group_ids = [var.security_group_id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name  = "${var.name}-${var.color}"
      Color = var.color
    }
  }
  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${var.name}-${var.color}" }
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.name}-${var.color}-asg"
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 180

  # enabled=false forces min=max=0, which scales the idle colour to zero.
  min_size         = var.enabled ? var.min_size : 0
  max_size         = var.enabled ? var.max_size : 0
  desired_capacity = var.enabled ? var.min_size : 0

  # Terraform waits for healthy ALB targets before reporting success.
  min_elb_capacity          = var.enabled ? var.min_size : 0
  wait_for_capacity_timeout = "15m"

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-${var.color}"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity] # let the scaling policy manage it
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name}-${var.color}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = 60
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}
