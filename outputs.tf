output "vpc_id" {
  value = aws_vpc.dev_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "ec2_public_ip" {
  value = aws_instance.dev_ec2.public_ip
}

output "ec2_private_ip" {
  value = aws_instance.dev_ec2.private_ip
}

