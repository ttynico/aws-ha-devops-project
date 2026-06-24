############################################
# Compute Module
# Launch Template + Auto Scaling Group running
# the Flask app across private subnets in 2+ AZs,
# registered to the ALB's target group.
############################################

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.ec2_instance_profile_name
  }

  vpc_security_group_ids = [var.app_sg_id]

  # No SSH key pair is configured on purpose. Operational access is
  # via AWS Systems Manager Session Manager (IAM-audited, no open
  # inbound ports, no key-pair sprawl) per the IAM role attached above.

  metadata_options {
    http_tokens                = "required" # enforce IMDSv2
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type            = "gp3"
      encrypted              = true
      delete_on_termination  = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    artifact_bucket = var.artifact_bucket
    artifact_key    = var.artifact_key
    aws_region      = var.aws_region
    app_port        = var.app_port
    project_name    = var.project_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-app"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Rolling instance refresh keeps the app available during
  # deploys instead of replacing every instance at once.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.project_name}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60
  }
}
