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

