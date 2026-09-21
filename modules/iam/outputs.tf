output "instance_profile_name" {
  value = aws_iam_instance_profile.profile.name
}

output "role_name" {
  value = aws_iam_role.ec2_role.name
}
