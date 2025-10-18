#To add ingress rules for all SGs

resource "aws_security_group" "account_ecs_sg" {
  name        = "account_ecs_sg"
  description = "Security Group for Account ECS tasks"
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "client_ecs_sg" {
  name        = "client-ecs-sg"
  description = "Security Group for Client ECS tasks"
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "allow_client_ecs_to_client_rds" {
  name        = "allow-client-ecs-to-client-rds"
  description = "Allow Postgres traffic from Client ECS tasks to Client RDS"
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "allow_transaction_lambda_to_transaction_rds" {
  name        = "allow-transaction-lambda-to-transaction-rds"
  description = "Allow Postgres traffic from Transaction Lambda to Transaction RDS"
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "allow_account_ecs_to_account_rds" {
  name        = "allow-account-ecs-to-account-rds"
  description = "Allow Postgres traffic from Account ECS tasks to Account RDS"
  vpc_id      = var.vpc_id
}
