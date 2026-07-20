resource "aws_instance" "dev_ec2" {
  ami                         = "ami-0fb18649b58075f5e"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.dev_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.profile.name
  key_name                    = "agent-key"

  tags = {
    Name = "Terraform-EC2"
  }
}
