variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-north-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet" {
  description = "CIDR block for Public Subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet" {
  description = "CIDR block for Private Subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone_public" {
  description = "Availability Zone for Public Subnet"
  type        = string
  default     = "eu-north-1a"
}

variable "availability_zone_private" {
  description = "Availability Zone for Private Subnet"
  type        = string
  default     = "eu-north-1b"
}

variable "ami_id" {
  description = "Ubuntu AMI ID"
  type        = string
  default     = "ami-0fb18649b58075f5e"
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "AWS EC2 Key Pair"
  type        = string
  default     = "agent-key"
}
