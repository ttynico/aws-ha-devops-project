output "alb_dns_name" {
  description = "Public URL of the load balancer - open this in a browser to test the app"
  value       = module.loadbalancer.alb_dns_name
}

output "artifact_bucket" {
  description = "S3 bucket the CI/CD pipeline uploads app.zip to"
  value       = aws_s3_bucket.artifacts.bucket
}

output "asg_name" {
  value = module.compute.asg_name
}

output "vpc_id" {
  value = module.network.vpc_id
}
