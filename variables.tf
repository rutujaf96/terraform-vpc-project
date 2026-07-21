variable "aws_region" {
  default = "eu-north-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet" {
  description = "CIDR block for Public Subnet"
  default     = "10.0.1.0/24"
}

variable "private_subnet" {
  description = "CIDR block for Private Subnet"
  default     = "10.0.2.0/24"
}

variable "availability_zone_public" {
  default = "eu-north-1a"
}

variable "availability_zone_private" {
  default = "eu-north-1b"
}

variable "ami_id" {
  default = "ami-0fb18649b58075f5e"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "key_name" {
  default = "agent-key"
}
