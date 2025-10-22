output "logging_queue_url" {
  description = "URL of the logging SQS queue"
  value       = aws_sqs_queue.logging_queue.url
}

output "logging_queue_arn" {
  description = "ARN of the logging SQS queue"
  value       = aws_sqs_queue.logging_queue.arn
}

output "logging_queue_name" {
  description = "Name of the logging SQS queue"
  value       = aws_sqs_queue.logging_queue.name
}

output "logging_queue_dlq_arn" {
  description = "ARN of the logging DLQ"
  value       = aws_sqs_queue.logging_queue_dlq.arn
}

output "logging_queue_dlq_url" {
  description = "URL of the logging DLQ"
  value       = aws_sqs_queue.logging_queue_dlq.url
}
