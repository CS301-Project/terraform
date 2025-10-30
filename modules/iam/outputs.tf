output "ecs_instance_profile_name" {
  value = aws_iam_instance_profile.ecs_instance_profile.name
}

output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_client_arn" {
  value = aws_iam_role.ecs_task_role_client.arn
}

output "ecs_task_role_account_arn" {
  value = aws_iam_role.ecs_task_role_account.arn
}