output "account_ecs_sg_id" {
  description = "Account ECS security group id"
  value       = aws_security_group.account_ecs_sg.id
}

output "client_ecs_sg_id" {
  description = "Client ECS security group id"
  value       = aws_security_group.client_ecs_sg.id
}

output "allow_client_ecs_to_client_rds_sg_id" {
  description = "Security Group ID allowing Client ECS to access Client RDS Postgres"
  value       = aws_security_group.allow_client_ecs_to_client_rds.id
}

output "allow_transaction_lambda_to_transaction_rds_sg_id" {
  description = "Security Group ID allowing Transaction Lambda to access Transaction RDS Postgres"
  value       = aws_security_group.allow_transaction_lambda_to_transaction_rds.id
}

output "allow_account_ecs_to_account_rds_sg_id" {
  description = "Security Group ID allowing Account ECS to access Account RDS Postgres"
  value       = aws_security_group.allow_account_ecs_to_account_rds.id
}
