variable "vpc_id" {
  description = "The ID of the main VPC"
  type        = string
}

variable "aws_region" {
  description = "The AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block of Main VPC"
  type        = string
}

variable "rds_subnet_cidr_blocks" {
  description = "List of Subnet CIDR blocks for RDS"
  type        = list(string)
}