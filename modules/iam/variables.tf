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