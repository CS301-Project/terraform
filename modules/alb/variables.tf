variable "assigned_sg_ids" {
  description = "List of Security Group IDs attached to the ALB"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of subnets to map ALB"
  type        = list(string)
}

variable "vpc_id" {
  description = "The ID of the VPC where security groups will be created"
  type        = string
}
