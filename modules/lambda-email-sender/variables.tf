variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "email-sender-lambda"
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue to trigger this Lambda"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for document uploads"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket for document uploads"
  type        = string
}

variable "sender_email" {
  description = "Verified sender email address in SES"
  type        = string
}

variable "template_name" {
  description = "Name of the SES email template"
  type        = string
}

variable "presigned_url_expiration" {
  description = "Expiration time for presigned URLs in seconds"
  type        = number
  default     = 86400  # 24 hours
}

variable "configuration_set" {
  description = "SES configuration set name"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda VPC configuration"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for Lambda"
  type        = list(string)
}

variable "batch_size" {
  description = "Maximum number of records to retrieve from SQS in a single batch"
  type        = number
  default     = 10
}

variable "logging_queue_arn" {
  description = "ARN of the logging SQS queue"
  type        = string
  default     = ""
}

variable "logging_queue_url" {
  description = "URL of the logging SQS queue"
  type        = string
  default     = ""
}
