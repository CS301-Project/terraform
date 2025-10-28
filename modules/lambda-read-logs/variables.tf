variable "logs_table_name" {
  description = "Name of the DynamoDB logs table"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB logs table"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda VPC configuration"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for Lambda"
  type        = list(string)
}