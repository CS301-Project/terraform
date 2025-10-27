variable "aws_region" {
  description = "AWS Region used"
  type        = string
}

variable "vpc_endpoint_sg_id" {
  description = "Security Group ID for VPC Endpoint"
  type        = string
}

variable "private_route_table_id" {
  description = "The ID of the private route table"
  type        = string
}