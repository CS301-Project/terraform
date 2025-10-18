resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-subnet-group" })
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-sg"
  description = "Allow MySQL access (staging)"
  vpc_id      = var.vpc_id

  # Staging only — open 3306; tighten later to specific sources
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "MySQL"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-sg" })
}

resource "aws_db_instance" "this" {
  identifier              = var.name
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage

  username                = var.db_username
  password                = var.db_password
  db_name                 = var.db_name

  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds.id]

  publicly_accessible     = true                # staging: Lambda outside VPC can connect
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = merge(var.tags, { Name = var.name })
}
