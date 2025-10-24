resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main-vpc"
  }
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "vpc_main_private_ecs_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
  tags = {
    Name        = "prod-private-ecs-ap-southeast-1a"
    Environment = "prod"
    Role        = "ecs"
  }
}

resource "aws_subnet" "vpc_main_private_ecs_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"
  tags = {
    Name        = "prod-private-ecs-ap-southeast-1b"
    Environment = "prod"
    Role        = "ecs"
  }
}

resource "aws_subnet" "vpc_main_private_rds_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-1a"
  tags = {
    Name        = "prod-private-db-ap-southeast-1a-primary"
    Environment = "prod"
    Role        = "db"
    Tier        = "primary"
  }
}

resource "aws_subnet" "vpc_main_private_rds_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-southeast-1b"
  tags = {
    Name        = "prod-private-db-ap-southeast-1b-backup"
    Environment = "prod"
    Role        = "db"
    Tier        = "backup"
  }
}

resource "aws_subnet" "vpc_main_public_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "ap-southeast-1a"
  tags = {
    Name        = "prod-public-ap-southeast-1a"
    Environment = "prod"
    Role        = "alb"
  }
}

resource "aws_subnet" "vpc_main_public_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "ap-southeast-1b"
  tags = {
    Name        = "prod-public-ap-southeast-1b"
    Environment = "prod"
    Role        = "alb"
  }
}

resource "aws_vpc_endpoint" "ecs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.vpc_main_private_ecs_az1.id, aws_subnet.vpc_main_private_ecs_az2.id]
  security_group_ids  = [var.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecs_agent" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecs-agent"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.vpc_main_private_ecs_az1.id, aws_subnet.vpc_main_private_ecs_az2.id]
  security_group_ids  = [var.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.vpc_main_private_ecs_az1.id, aws_subnet.vpc_main_private_ecs_az2.id]
  security_group_ids  = [var.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.vpc_main_private_ecs_az1.id, aws_subnet.vpc_main_private_ecs_az2.id]
  security_group_ids  = [var.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.vpc_main_private_ecs_az1.id, aws_subnet.vpc_main_private_ecs_az2.id]
  security_group_ids  = [var.vpc_endpoint_sg_id]
  private_dns_enabled = true
}
