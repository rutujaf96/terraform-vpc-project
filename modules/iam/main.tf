resource "aws_iam_role" "ec2_role" {

  name = "Terraform-EC2-Role-2"

  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Principal = {

          Service = "ec2.amazonaws.com"

        }

        Action = "sts:AssumeRole"

      }

    ]

  })

}

resource "aws_iam_instance_profile" "profile" {

  name = "Terraform-Profile-2"

  role = aws_iam_role.ec2_role.name

}
