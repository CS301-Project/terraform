output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.id
}

output "user_pool_domain" {
  description = "Domain of the Cognito User Pool"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "root_admin_group_id" {
  description = "ID of the root_admin group"
  value       = aws_cognito_user_group.root_admin.id
}

output "admin_group_id" {
  description = "ID of the admin group"
  value       = aws_cognito_user_group.admin.id
}

output "agent_group_id" {
  description = "ID of the agent group"
  value       = aws_cognito_user_group.agent.id
}
