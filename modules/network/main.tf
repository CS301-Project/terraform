resource "aws_internet_gateway" "main" {
  vpc_id = var.vpc_id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_az1" {
  subnet_id      = var.public_subnet_az1_id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = var.public_subnet_az2_id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = var.vpc_id
  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private_ecs_az1" {
  subnet_id      = var.private_ecs_subnet_az1_id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_ecs_az2" {
  subnet_id      = var.private_ecs_subnet_az2_id
  route_table_id = aws_route_table.private.id
}