variable "name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}

variable "db_username" {
  type = string
}
variable "db_password" {
  type = string
}
variable "db_name" {
  type    = string
  default = "crmdb"
}
variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "tags" {
  type = map(string)
}
