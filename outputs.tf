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


output "lambda_function_name" {
  description = "URL checker Lambda function name"
  value       = module.lambda_url_checker.lambda_function_name
}

output "lambda_function_arn" {
  description = "URL checker Lambda function ARN"
  value       = module.lambda_url_checker.lambda_function_arn
}

output "lambda_application_url" {
  description = "Application URL used by Lambda"
  value       = module.lambda_url_checker.application_url
}

output "lambda_cloudwatch_log_group" {
  description = "Lambda CloudWatch log group"
  value       = module.lambda_url_checker.cloudwatch_log_group
}
