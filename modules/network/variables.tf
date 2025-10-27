variable "vpc_id" {
  description = "The ID of the VPC where IGW will be created"
  type        = string
}

variable "public_subnet_az1_id" {
  description = "The ID of the public subnet in ap-southeast-1a"
  type        = string
}

variable "public_subnet_az2_id" {
  description = "The ID of the public subnet in ap-southeast-1b"
  type        = string
}

variable "private_ecs_subnet_az1_id" {
  description = "The ID of the private ECS subnet in ap-southeast-1a"
  type        = string
}

variable "private_ecs_subnet_az2_id" {
  description = "The ID of the private ECS subnet in ap-southeast-1b"
  type        = string
}
