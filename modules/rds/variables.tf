variable "rds_primary_subnet_id" {
  description = "The ID of the subnet where primary RDS will be created"
  type        = string
}

variable "rds_backup_subnet_id" {
  description = "The ID of the subnet where backup RDS will be created"
  type        = string
}
