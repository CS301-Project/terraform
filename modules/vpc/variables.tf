variable "name" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnet_cidr" { type = string }
variable "tags" { type = map(string) }
variable "public_subnet_cidr_2" {
  type        = string
  default     = "10.0.2.0/24"
  description = "Second public subnet in another AZ for RDS"
}
variable "az_1" {}
variable "az_2" {}
