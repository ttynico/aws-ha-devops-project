############################################
# Root module - wires network, security,
# load balancer, and compute modules together,
# plus the artifact bucket and basic monitoring.
############################################

module "network" {
  source = "./modules/network"

  project_name         = var.project_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  single_nat_gateway    = var.single_nat_gateway
}

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id
  app_port     = var.app_port
}

module "loadbalancer" {
  source = "./modules/loadbalancer"

  project_name        = var.project_name
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  alb_sg_id           = module.security.alb_sg_id
  app_port            = var.app_port
  health_check_path   = var.health_check_path
  certificate_arn     = var.certificate_arn
  access_logs_bucket  = aws_s3_bucket.alb_logs.bucket

  # The ALB log-delivery account needs the bucket policy in place
  # *before* the ALB is created with access logging enabled, or the
  # apply fails with an access-denied error. Module depends_on
  # enforces that ordering explicitly.
  depends_on = [aws_s3_bucket_policy.alb_logs]
}

module "compute" {
  source = "./modules/compute"

  project_name               = var.project_name
  aws_region                 = var.aws_region
  private_subnet_ids         = module.network.private_subnet_ids
  app_sg_id                  = module.security.app_sg_id
  ec2_instance_profile_name  = module.security.ec2_instance_profile_name
  target_group_arn           = module.loadbalancer.target_group_arn
  instance_type              = var.instance_type
  app_port                   = var.app_port
  min_size                   = var.min_size
  max_size                   = var.max_size
  desired_capacity           = var.desired_capacity
  artifact_bucket            = aws_s3_bucket.artifacts.bucket
  artifact_key               = var.artifact_key
}

# ---------- S3 bucket for app deployment artifacts ----------
# The CI/CD pipeline uploads app.zip here; EC2 instances pull
# from it on boot / instance refresh.
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-artifacts-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------- S3 bucket for ALB access logs ----------
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.project_name}-alb-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ALB requires a bucket policy granting its AWS-managed account
# log-delivery permission. elb-account-id varies by region; see
# https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.alb_logs.arn}/alb/*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

# CloudWatch ALB metrics expect the ARN *suffix* (e.g. "targetgroup/name/id"),
# not the full ARN, as the dimension value.
locals {
  target_group_dimension = regex("(targetgroup/.+)$", module.loadbalancer.target_group_arn)[0]
}

# ---------- Monitoring / Alerting ----------
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Average ASG CPU above 80% for 2 consecutive minutes"
  dimensions = {
    AutoScalingGroupName = module.compute.asg_name
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project_name}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "One or more targets failing ALB health checks"
  dimensions = {
    TargetGroup = local.target_group_dimension
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "More than 5 server errors from app targets in 1 minute"
  treat_missing_data  = "notBreaching"
  dimensions = {
    TargetGroup = local.target_group_dimension
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
}
