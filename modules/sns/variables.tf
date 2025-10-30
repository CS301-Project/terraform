variable "topic_name" {
  description = "Name of the SNS topic"
  type        = string
  default     = "textract-completion-topic"
}

variable "enable_encryption" {
  description = "Enable KMS encryption for the SNS topic"
  type        = bool
  default     = false
}
