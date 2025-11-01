variable "account_db_secret_arn" {
  description = "ARN of the account database secret"
  type        = string
}

variable "client_db_secret_arn" {
  description = "ARN of the client database secret"
  type        = string
}

variable "rds_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt RDS secrets"
  type        = string
}

variable "sqs_logging_arn" {
  description = "ARN of the SQS queue for logging"
  type        = string
}

variable "verification_request_queue_arn" {
  description = "ARN of the verification request SQS queue"
  type        = string
}

variable "verification_results_queue_arn" {
  description = "ARN of the verification results SQS queue"
  type        = string
}