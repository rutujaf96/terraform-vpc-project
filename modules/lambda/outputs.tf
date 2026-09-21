output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.url_checker.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.url_checker.arn
}

output "lambda_role_name" {
  description = "Lambda execution IAM role name"
  value       = aws_iam_role.lambda_role.name
}

output "cloudwatch_log_group" {
  description = "Lambda CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "application_url" {
  description = "Application URL checked by Lambda"
  value       = var.application_url
}
