variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "app_port" {
  type    = number
  default = 5000
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Leave empty to serve HTTP only."
  type        = string
  default     = ""
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}

variable "access_logs_bucket" {
  description = "S3 bucket name for ALB access logs. Leave empty to disable."
  type        = string
  default     = ""
}
