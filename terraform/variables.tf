variable "project_name" {
  description = "Short name used to prefix/tag all resources"
  type        = string
  default     = "ha-app"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway instead of one per AZ. Set false for full HA, true to save cost in a lab."
  type        = bool
  default     = false
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "app_port" {
  type    = number
  default = 5000
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 4
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "artifact_key" {
  description = "S3 key the CI/CD pipeline uploads the app zip to"
  type        = string
  default     = "app.zip"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Leave empty for HTTP-only (fine for initial testing without a domain)."
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm (SNS) notifications. Leave empty to skip the email subscription."
  type        = string
  default     = ""
}
