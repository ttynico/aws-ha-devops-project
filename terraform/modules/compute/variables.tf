variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "app_sg_id" {
  type = string
}

variable "ec2_instance_profile_name" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "app_port" {
  type    = number
  default = 5000
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

variable "artifact_bucket" {
  description = "S3 bucket the CI/CD pipeline uploads the app artifact to"
  type        = string
}

variable "artifact_key" {
  description = "S3 key of the app artifact zip"
  type        = string
  default     = "app.zip"
}
