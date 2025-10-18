resource "aws_network_acl" "private_db_acl" {
  vpc_id = var.vpc_id

  egress { # out-bound traffic
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "10.3.0.0/18"
    from_port  = 443
    to_port    = 443
  }

  ingress { # in-bound traffic
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.3.0.0/18"
    from_port  = 80
    to_port    = 80
  }

  tags = {
    Name        = "private-db-subnet-network-acl"
    Environment = "prod"
  }
}

resource "aws_network_acl" "private_ecs_acl" {
  vpc_id = var.vpc_id

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "10.3.0.0/18"
    from_port  = 443
    to_port    = 443
  }

  ingress { # in-bound traffic
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.3.0.0/18"
    from_port  = 80
    to_port    = 80
  }

  tags = {
    Name        = "private-db-subnet-network-acl"
    Environment = "prod"
  }
}

