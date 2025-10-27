output "vpc_id" {
  value = aws_vpc.main.id
}

output "ecs_az1_subnet_id" {
  value = aws_subnet.vpc_main_private_ecs_az1.id
}

output "ecs_az2_subnet_id" {
  value = aws_subnet.vpc_main_private_ecs_az2.id
}

output "rds_primary_subnet_id" {
  value = aws_subnet.vpc_main_private_rds_az1.id
}

output "rds_backup_subnet_id" {
  value = aws_subnet.vpc_main_private_rds_az2.id
}

output "public_subnet_az1_id" {
  value = aws_subnet.vpc_main_public_az1.id
}

output "public_subnet_az2_id" {
  value = aws_subnet.vpc_main_public_az2.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "rds_primary_subnet_cidr" {
  value = aws_subnet.vpc_main_private_rds_az1.cidr_block
}

output "rds_backup_subnet_cidr" {
  value = aws_subnet.vpc_main_private_rds_az2.cidr_block
}