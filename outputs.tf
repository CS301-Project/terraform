# Logging Infrastructure Outputs

output "logging_queue_url" {
  description = "URL of the SQS logging queue - use this in your services to send log messages"
  value       = module.sqs.logging_queue_url
}

output "logging_queue_arn" {
  description = "ARN of the SQS logging queue"
  value       = module.sqs.logging_queue_arn
}

output "logging_dlq_url" {
  description = "URL of the dead letter queue for failed log messages"
  value       = module.sqs.logging_queue_dlq_url
}

output "dynamodb_logs_table_name" {
  description = "Name of the DynamoDB table storing logs"
  value       = module.dynamodb.logs_table_name
}

output "lambda_log_processor_name" {
  description = "Name of the Lambda function processing logs"
  value       = module.lambda_logging.lambda_function_name
}

# output "site_fqdn" {
#   value = module.route53.fqdn
# }

output "cloudfront_domain_name" {
  value = module.cloudfront.domain_name
}

output "cloudfront_distribution_id" {
  value = module.cloudfront.distribution_id
}

output "frontend_bucket" {
  value = module.s3_frontend.bucket_name
}

# output "site_fqdn" {
#   value = module.route53.fqdn
# }

output "api_endpoint" {
  description = "API Gateway endpoint URL for reading logs"
  value       = module.api_gateway.api_endpoint
}

output "api_id" {
  description = "API Gateway REST API ID"
  value       = module.api_gateway.api_id
}