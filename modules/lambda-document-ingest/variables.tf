variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "document-ingest-lambda"
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for document uploads"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for Textract completion notifications"
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
