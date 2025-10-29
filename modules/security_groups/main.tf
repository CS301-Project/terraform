data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${var.aws_region}.s3"
}

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

resource "aws_security_group" "lambda_logging_sg" {
  name        = "lambda-logging-sg"
  description = "Security Group for Lambda log processor"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "lambda-logging-sg"
    Environment = "production"
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id
  tags = {
    Name = "alb-sg"
  }
}

resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "vpc-endpoint-sg"
  description = "Allow ECS instances to talk to AWS VPC endpoints"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "account_ecs_ingress_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.account_ecs_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "account_ecs_egress_vpc_endpoint" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.account_ecs_sg.id
  source_security_group_id = aws_security_group.vpc_endpoint_sg.id
}

resource "aws_security_group_rule" "account_ecs_egress_rds" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.account_ecs_sg.id
  source_security_group_id = aws_security_group.allow_account_ecs_to_account_rds.id
}

resource "aws_security_group_rule" "client_ecs_ingress_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.client_ecs_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "client_ecs_egress_vpc_endpoint" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.client_ecs_sg.id
  source_security_group_id = aws_security_group.vpc_endpoint_sg.id
}

resource "aws_security_group_rule" "client_ecs_egress_rds" {
  type              = "egress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.client_ecs_sg.id
  cidr_blocks       = var.rds_subnet_cidr_blocks
}

resource "aws_security_group_rule" "client_rds_ingress_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_client_ecs_to_client_rds.id
  source_security_group_id = aws_security_group.client_ecs_sg.id
}

resource "aws_security_group_rule" "account_rds_ingress_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_account_ecs_to_account_rds.id
  source_security_group_id = aws_security_group.account_ecs_sg.id
}

resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS from anywhere"
}

resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP from anywhere"
}

resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = [var.vpc_cidr]
  description       = "Allow outbound to main VPC only"
}

resource "aws_security_group_rule" "vpc_endpoint_ingress_account_ecs" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoint_sg.id
  source_security_group_id = aws_security_group.account_ecs_sg.id
  description              = "Allow HTTPS from Account ECS tasks"
}

resource "aws_security_group_rule" "vpc_endpoint_ingress_client_ecs" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoint_sg.id
  source_security_group_id = aws_security_group.client_ecs_sg.id
  description              = "Allow HTTPS from Client ECS tasks"
}

resource "aws_security_group_rule" "account_ecs_egress_s3" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.account_ecs_sg.id
  prefix_list_ids   = [data.aws_prefix_list.s3.id]
  description       = "Allow ECS to access S3 via VPC endpoint"
}

resource "aws_security_group_rule" "client_ecs_egress_s3" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.client_ecs_sg.id
  prefix_list_ids   = [data.aws_prefix_list.s3.id]
  description       = "Allow ECS to access S3 via VPC endpoint"
}

resource "aws_security_group_rule" "client_ecs_egress_dns" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  security_group_id = aws_security_group.client_ecs_sg.id
  cidr_blocks       = [var.vpc_cidr]
  description       = "Allow DNS resolution within VPC"
}
