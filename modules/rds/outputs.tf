output "account_db_endpoint" {
  description = "Connection endpoint for account database"
  value       = aws_db_instance.account_db.address
}

output "account_db_username" {
  description = "Master username for account database"
  value       = aws_db_instance.account_db.username
}

output "account_db_secret_arn" {
  description = "ARN of the secret containing account database password"
  value       = aws_db_instance.account_db.master_user_secret[0].secret_arn
}

output "client_db_endpoint" {
  description = "Connection endpoint for client database"
  value       = aws_db_instance.client_db.address
}

output "client_db_username" {
  description = "Master username for client database"
  value       = aws_db_instance.client_db.username
}

output "client_db_secret_arn" {
  description = "ARN of the secret containing client database password"
  value       = aws_db_instance.client_db.master_user_secret[0].secret_arn
}

output "rds_secret_key_id" {
  description = "KMS Key ID used to encrypt RDS secrets"
  value       = aws_kms_key.rds_kms_key.arn
}