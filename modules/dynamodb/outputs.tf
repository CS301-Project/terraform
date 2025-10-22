output "logs_table_name" {
  description = "Name of the DynamoDB logs table"
  value       = aws_dynamodb_table.logs_table.name
}

output "logs_table_arn" {
  description = "ARN of the DynamoDB logs table"
  value       = aws_dynamodb_table.logs_table.arn
}

output "logs_table_id" {
  description = "ID of the DynamoDB logs table"
  value       = aws_dynamodb_table.logs_table.id
}
