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
