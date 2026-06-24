output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.ec2_profile.name
}

output "ec2_role_arn" {
  value = aws_iam_role.ec2_role.arn
}
