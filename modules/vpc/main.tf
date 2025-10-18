resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main-vpc"
  }
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
