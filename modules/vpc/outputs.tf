output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "Public subnet 1 ID"
  value       = aws_subnet.public_1.id
}

output "public_subnet_id_2" {
  description = "Public subnet 2 ID"
  value       = aws_subnet.public_2.id
}

output "vpc_cidr" {
  description = "VPC CIDR"
  value       = var.vpc_cidr
}
