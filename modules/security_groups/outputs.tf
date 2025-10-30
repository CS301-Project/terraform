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

output "lambda_logging_sg_id" {
  description = "Security Group ID for Lambda logging function"
  value       = aws_security_group.lambda_logging_sg.id
}

output "alb_sg_id" {
  description = "Security Group ID defining ingress and egress rules for ALB"
  value       = aws_security_group.alb_sg.id
}

output "vpc_endpoint_sg_id" {
  description = "Security Group ID for VPC endpoint"
  value       = aws_security_group.vpc_endpoint_sg.id
}

output "lambda_verification_sg_id" {
  description = "Security Group ID for verification Lambda functions"
  value       = aws_security_group.lambda_verification_sg.id
}
