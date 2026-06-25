variable "project_name" {
  description = "Name prefix used for tagging all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the security groups belong to"
  type        = string
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 5000
}

variable "artifact_bucket_name" {
  description = "Name of the S3 bucket containing the app deployment artifact"
  type        = string
}
