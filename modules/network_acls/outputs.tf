output "db_acl_id" {
  value = aws_network_acl.private_db_acl.id
}

output "ecs_acl_id" {
  value = aws_network_acl.private_ecs_acl.id
}