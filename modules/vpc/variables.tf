variable "name" {
  description = "Name prefix for all VPC resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR for first public subnet"
  type        = string
}

variable "public_subnet_cidr_2" {
  description = "CIDR for second public subnet"
  type        = string
}

variable "az_1" {
  description = "Availability Zone for first subnet"
  type        = string
}

variable "az_2" {
  description = "Availability Zone for second subnet"
  type        = string
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}
