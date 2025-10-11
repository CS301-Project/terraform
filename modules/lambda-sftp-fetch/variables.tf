variable "name" { type = string }

# SFTP (password auth)
variable "sftp_host" { type = string }
variable "sftp_port" { type = number }
variable "sftp_user" { type = string }
variable "sftp_password" {
  type      = string
  sensitive = true
  default   = ""
}

# DB connection
variable "db_endpoint" { type = string }
variable "db_port" { type = number }
variable "db_name" { type = string }
variable "db_user" { type = string }
variable "db_password" { type = string }

variable "tags" { type = map(string) }
