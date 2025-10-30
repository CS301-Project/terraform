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

# Verification Request Queue Outputs
output "verification_request_queue_url" {
  description = "URL of the verification request SQS queue"
  value       = aws_sqs_queue.verification_request_queue.url
}

output "verification_request_queue_arn" {
  description = "ARN of the verification request SQS queue"
  value       = aws_sqs_queue.verification_request_queue.arn
}

output "verification_request_queue_name" {
  description = "Name of the verification request SQS queue"
  value       = aws_sqs_queue.verification_request_queue.name
}

# Verification Results Queue Outputs
output "verification_results_queue_url" {
  description = "URL of the verification results SQS queue"
  value       = aws_sqs_queue.verification_results_queue.url
}

output "verification_results_queue_arn" {
  description = "ARN of the verification results SQS queue"
  value       = aws_sqs_queue.verification_results_queue.arn
}

output "verification_results_queue_name" {
  description = "Name of the verification results SQS queue"
  value       = aws_sqs_queue.verification_results_queue.name
}
