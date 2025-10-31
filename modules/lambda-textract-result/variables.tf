variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "textract-result-lambda"
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for Textract completion notifications"
  type        = string
}

variable "verification_results_queue_arn" {
  description = "ARN of the verification results SQS queue"
  type        = string
}

variable "verification_results_queue_url" {
  description = "URL of the verification results SQS queue"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda VPC configuration"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for Lambda"
  type        = list(string)
}

variable "document_bucket_arn" {
  description = "ARN of the S3 bucket containing documents to be deleted after processing"
  type        = string
}
