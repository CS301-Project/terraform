variable "env_name" {
  description = "Environment name, used for naming resources"
  type        = string
}

variable "enable_log_group" {
  description = "Whether to create a CloudWatch Log Group for CloudTrail"
  type        = bool
  default     = true
}
