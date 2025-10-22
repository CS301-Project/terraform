output "lambda_function_arn" {
  description = "ARN of the log processor Lambda function"
  value       = aws_lambda_function.log_processor.arn
}

output "lambda_function_name" {
  description = "Name of the log processor Lambda function"
  value       = aws_lambda_function.log_processor.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_logging_role.arn
}

output "lambda_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_log_group.name
}
