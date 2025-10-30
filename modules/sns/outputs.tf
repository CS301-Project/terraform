output "topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.textract_completion.arn
}

output "topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.textract_completion.name
}

output "topic_id" {
  description = "ID of the SNS topic"
  value       = aws_sns_topic.textract_completion.id
}
