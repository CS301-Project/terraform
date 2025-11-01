output "client_asg_id" {
  value = aws_autoscaling_group.client_nodes.id
}

output "account_asg_id" {
  value = aws_autoscaling_group.account_nodes.id
}

output "client_scale_out_policy_arn" {
  value = aws_appautoscaling_policy.client_scale_out.arn
}

output "client_scale_in_policy_arn" {
  value = aws_appautoscaling_policy.client_scale_in.arn
}

output "account_scale_out_policy_arn" {
  value = aws_appautoscaling_policy.account_scale_out.arn
}

output "account_scale_in_policy_arn" {
  value = aws_appautoscaling_policy.account_scale_in.arn
}
