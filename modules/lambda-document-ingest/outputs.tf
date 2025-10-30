output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.document_ingest.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.document_ingest.arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.document_ingest.invoke_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.document_ingest_lambda.arn
}

output "lambda_permission_id" {
  description = "ID of the Lambda permission for S3"
  value       = aws_lambda_permission.allow_s3_invoke.id
}

output "textract_sns_role_arn" {
  description = "ARN of the Textract SNS role"
  value       = aws_iam_role.textract_sns_role.arn
}
