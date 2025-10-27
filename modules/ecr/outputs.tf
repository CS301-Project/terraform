output "client_repository_url" {
  value       = aws_ecr_repository.client.repository_url
  description = "The URL of the client repository"
}

output "account_repository_url" {
  value       = aws_ecr_repository.account.repository_url
  description = "The URL of the account repository"
}