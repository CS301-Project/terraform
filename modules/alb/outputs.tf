output "account_alb_target_group_arn" {
  value = aws_lb_target_group.account.arn
}

output "client_alb_target_group_arn" {
  value = aws_lb_target_group.client.arn
}

