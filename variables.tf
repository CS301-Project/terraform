variable "aws_region" {
  type    = string
  default = "ap-southeast-1" # Singapore
}

variable "az" {
  type    = string
  default = "ap-southeast-1a"
}

variable "tags" {
  type = map(string)
  default = {
    Project = "crm-sftp-demo"
  }
}
variable "allowed_ssh_cidr" {
  type        = string
  description = "Your IP in CIDR (e.g., 203.0.113.5/32). Use 0.0.0.0/0 only for quick tests."
  default     = "0.0.0.0/0"
}

variable "sftp_user_pubkey" {
  type        = string
  description = "Contents of your crm-sftp.pub"
}
variable "sftp_host" { type = string } # e.g., module.sftp.sftp_public_ip
variable "sftp_port" {
  type    = number
  default = 22
}
variable "sftp_user" {
  type    = string
  default = "bankhost"
}
variable "sftp_private_key_pem" {
  type        = string
  description = "Private key content for SFTP user (crm-sftp). Keep safe."
  sensitive   = true
}
variable "db_username" {
  type    = string
  default = "admin"
}
variable "db_password" {
  type        = string
  sensitive   = true
  description = "Database password"
}

variable "az_1" {
  type    = string
  default = "ap-southeast-1a"
}
variable "az_2" {
  type    = string
  default = "ap-southeast-1b"
}
