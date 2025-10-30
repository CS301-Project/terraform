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

variable "account_db_endpoint" {
  description = "AWS Provisioned endpoint for Account RDS"
}

variable "client_db_endpoint" {
  description = "AWS Provisioned endpoint for Client RDS"
}

variable "account_db_secret_arn" {
  description = "ARN of the secret containing account database password"
  type        = string
}

variable "client_db_secret_arn" {
  description = "ARN of the secret containing client database password"
  type        = string
}

variable "account_db_username" {
  description = "Master username for account database"
  type        = string
}

variable "client_db_username" {
  description = "Master username for client database"
  type        = string
}

variable "client_repository_url" {
  description = "ECR repository URL for client service"
  type        = string
}

variable "account_repository_url" {
  description = "ECR repository URL for account service"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "sqs_logging_url" {
  description = "URL of the SQS logging queue"
  type        = string
}

variable "ecs_task_role_client_arn" {
  description = "ARN of the ECS task role for client service"
  type        = string
}

variable "ecs_task_role_account_arn" {
  description = "ARN of the ECS task role for account service"
  type        = string
}