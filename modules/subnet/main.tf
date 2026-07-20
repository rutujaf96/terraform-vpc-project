resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = var.public_subnet
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1a"

  tags = {
    Name = "Public-Subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = var.private_subnet
  availability_zone = "eu-north-1b"

  tags = {
    Name = "Private-Subnet"
  }
}


