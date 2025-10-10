variable "name"                 { type = string }
# Remove vpc_id and subnet_ids (not needed outside VPC)

# SFTP
variable "sftp_host"            { type = string }
variable "sftp_port"            { type = number }
variable "sftp_user"            { type = string }
variable "sftp_private_key_pem" { type = string }

# DB connection (passed from root)
variable "db_endpoint" { type = string }
variable "db_port"     { type = number }
variable "db_name"     { type = string }
variable "db_user"     { type = string }
variable "db_password" { type = string }

variable "tags" { type = map(string) }
