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
  value       = module.api_gateway.api_invoke_url
}

output "api_id" {
  description = "API Gateway REST API ID"
  value       = module.api_gateway.api_id
}

# Cognito Outputs
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_domain" {
  description = "Cognito User Pool Domain"
  value       = module.cognito.user_pool_domain
}

output "cognito_login_endpoint" {
  description = "Cognito login endpoint URL"
  value       = "https://${module.cognito.user_pool_domain}.auth.ap-southeast-1.amazoncognito.com/login"
}

output "cognito_token_endpoint" {
  description = "Cognito OAuth token endpoint"
  value       = "https://${module.cognito.user_pool_domain}.auth.ap-southeast-1.amazoncognito.com/oauth2/token"
}

output "root_admin_permanent_password" {
  description = "Permanent password for root_admin user (username: root_admin, email: admin@example.com) - use to login directly, no password change required"
  value       = module.cognito.root_admin_permanent_password
  sensitive   = true
}