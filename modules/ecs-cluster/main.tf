resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
}

variable "cluster_name" {
  type        = string
  description = "Name of the ECS cluster"
}
