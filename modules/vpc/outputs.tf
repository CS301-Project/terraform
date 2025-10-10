output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_id" { value = aws_subnet.public_1.id }
output "public_route_table" { value = aws_route_table.public.id }
output "igw_id" { value = aws_internet_gateway.igw.id }
output "public_subnet_id_2" {
  value = aws_subnet.public_2.id
}
