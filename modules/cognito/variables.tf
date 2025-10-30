variable "user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
  default     = "crm-user-pool"
}

variable "user_pool_client_name" {
  description = "Name of the Cognito User Pool Client"
  type        = string
  default     = "crm-app-client"
}

variable "user_pool_domain" {
  description = "Domain name for the Cognito User Pool (must be globally unique)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "root_admin_email" {
  description = "Email for the root admin user"
  type        = string
}
