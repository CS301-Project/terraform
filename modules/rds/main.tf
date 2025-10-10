resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}


resource "aws_security_group" "rds" {
  name        = "${var.name}-sg"
  description = "Allow MySQL access from Lambda"
  vpc_id      = var.vpc_id

  ingress {
    description = "MySQL from anywhere (restrict later)"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier             = var.name
  allocated_storage      = var.allocated_storage
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.instance_class
  username               = var.db_username
  password               = var.db_password
  db_name                = var.db_name
  publicly_accessible    = true # simple demo
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  deletion_protection    = false
  tags                   = var.tags
}
