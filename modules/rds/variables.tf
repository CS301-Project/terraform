variable "rds_subnet_ids" {
  description = "List of subnet IDs for RDS"
  type        = list(string)
}

variable "transaction_rds_permitted_sgs" {
  description = "List of Security Group IDs allowed to access the Transaction RDS instance"
  type        = list(string)
}

variable "client_rds_permitted_sgs" {
  description = "List of Security Group IDs allowed to access the Client RDS instance"
  type        = list(string)
}

variable "account_rds_permitted_sgs" {
  description = "List of Security Group IDs allowed to access the Account RDS instance"
  type        = list(string)
}