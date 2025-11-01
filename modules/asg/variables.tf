variable "client_launch_template_id" {
  description = "The ID of the launch template for Client ECS instances"
  type        = string
}

variable "account_launch_template_id" {
  description = "The ID of the launch template for Account ECS instances"
  type        = string
}

variable "ecs_private_subnet_ids" {
  description = "The IDs of the private subnets where ECS instances will be launched"
  type        = list(string)
}

variable "client_cluster_name" {
  description = "The name of the Client ECS cluster"
  type        = string
}

variable "account_cluster_name" {
  description = "The name of the Account ECS cluster"
  type        = string
}

variable "client_service_name" {
  description = "The name of the Client ECS service"
  type        = string
}

variable "account_service_name" {
  description = "The name of the Account ECS service"
  type        = string
}
