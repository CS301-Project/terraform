output "lambda_function_name" {
  description = "Name of the Cognito Lambda function"
  value       = aws_lambda_function.cognito_handler.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Cognito Lambda function"
  value       = aws_lambda_function.cognito_handler.arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN for the Cognito Lambda (used by API Gateway)"
  value       = aws_lambda_function.cognito_handler.invoke_arn
}

output "lambda_role_arn" {
  description = "IAM role ARN for the Lambda function"
  value       = aws_iam_role.lambda_cognito.arn
}

output "lambda_role_name" {
  description = "IAM role name for the Lambda function"
  value       = aws_iam_role.lambda_cognito.name
}
