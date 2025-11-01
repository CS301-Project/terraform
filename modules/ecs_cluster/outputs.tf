output "client_cluster_id" {
  value = aws_ecs_cluster.client.id
}

output "account_cluster_id" {
  value = aws_ecs_cluster.account.id
}

output "client_launch_template_id" {
  value = aws_launch_template.client_nodes.id
}

output "account_launch_template_id" {
  value = aws_launch_template.account_nodes.id
}

output "client_cluster_name" {
  value = aws_ecs_cluster.client.name
}

output "account_cluster_name" {
  value = aws_ecs_cluster.account.name
}

output "client_service_name" {
  value = aws_ecs_service.client.name
}

output "account_service_name" {
  value = aws_ecs_service.account.name
}
