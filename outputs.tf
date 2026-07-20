output "vpc_id" {

  value = module.vpc.vpc_id

}


output "public_subnet_id" {

  value = module.subnet.public_subnet_id

}


output "private_subnet_id" {

  value = module.subnet.private_subnet_id

}


output "ec2_public_ip" {

  value = module.ec2.public_ip

}


output "ec2_private_ip" {

  value = module.ec2.private_ip

}
