variable "db_acl_id" {
  description = "The ID of the network ACL for the private database subnet"
  type        = string
}

variable "ecs_acl_id" {
  description = "The ID of the network ACL fort he private app subnet"
  type        = string
}

variable "ecs_az1_subnet_id" {
  description = "The ID of the ecs subnet in ap-southeast-1a"
  type        = string
}

variable "ecs_az2_subnet_id" {
  description = "The ID of the ecs subnet in ap-southeast-1b"
  type        = string
}

variable "rds_primary_subnet_id" {
  description = "The ID of the primary database subnet"
  type        = string
}

variable "rds_backup_subnet_id" {
  description = "The ID of the backup database subnet"
  type        = string
}
