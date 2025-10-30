output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.textract_result.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.textract_result.arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.textract_result.invoke_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.textract_result_lambda.arn
}
