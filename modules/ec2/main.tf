resource "aws_instance" "dev_ec2" {

  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id = var.subnet_id

  vpc_security_group_ids = var.security_group_ids

  iam_instance_profile = var.iam_instance_profile

  associate_public_ip_address = true

  key_name = var.key_name

  tags = {
    Name = "Terraform-EC2"
  }

}
