variable "account_ecs_sg_id" {
  description = "The ID of the security group for Account ECS"
  type        = string
}

variable "client_ecs_sg_id" {
  description = "The ID of the security group for Client ECS"
  type        = string
}

variable "ecs_private_subnet_ids" {
  description = "The IDs of the private subnets that ECS instances will be provisioned in"
  type        = list(string)
}

variable "account_alb_target_group_arn" {
  description = "The ARN of the ALB target group for the Account service"
  type        = string
}

variable "client_alb_target_group_arn" {
  description = "The ARN of the ALB target group for the Client service"
  type        = string
}

variable "ecs_instance_profile_name" {
  description = "IAM Instance Profile for EC2 to assume to connect to ECS cluster"
  type        = string
}
