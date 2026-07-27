terraform {
  backend "s3" {
    bucket  = "rutuja-terraform-state-560904638794"
    key     = "terraform-vpc/dev/terraform.tfstate"
    region  = "eu-north-1"
    encrypt = true
  }
}
