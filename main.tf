module "vpc" {

  source = "./modules/vpc"

  vpc_cidr = var.vpc_cidr

}


module "subnet" {

  source = "./modules/subnet"

  vpc_id = module.vpc.vpc_id

  public_subnet = var.public_subnet

  private_subnet = var.private_subnet

  availability_zone_public  = var.availability_zone_public

  availability_zone_private = var.availability_zone_private

}


module "security_group" {

  source = "./modules/security-group"

  vpc_id = module.vpc.vpc_id

}


module "iam" {

  source = "./modules/iam"

}


module "ec2" {

  source = "./modules/ec2"


  subnet_id = module.subnet.public_subnet_id


  security_group_ids = [
    module.security_group.security_group_id
  ]


  iam_instance_profile = module.iam.instance_profile_name


  ami_id = var.ami_id

  instance_type = var.instance_type

  key_name = var.key_name


}
