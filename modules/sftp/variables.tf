variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "allowed_ssh_cidr" { type = string }
variable "sftp_username" { type = string }
variable "sftp_user_pubkey" { type = string }
variable "instance_type" { type = string }
variable "tags" { type = map(string) }
