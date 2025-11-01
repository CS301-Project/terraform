variable "read_lambda_invoke_arn" {
  description = "Invoke ARN of the read Lambda function"
  type        = string
}

variable "read_lambda_function_name" {
  description = "Name of the read Lambda function"
  type        = string
}

variable "enable_cognito_auth" {
  description = "Enable Cognito authorization for protected endpoints"
  type        = bool
  default     = false
}

variable "cognito_user_pool_arns" {
  description = "List of Cognito User Pool ARNs for authorization"
  type        = list(string)
  default     = []
}

variable "cognito_lambda_invoke_arn" {
  description = "Invoke ARN of the Cognito Lambda function"
  type        = string
  default     = null
}

variable "cognito_lambda_function_name" {
  description = "Name of the Cognito Lambda function"
  type        = string
  default     = null
}

variable "user_pool_arn" {
  description = "ARN of the Cognito User Pool for authorization"
  type        = string
}