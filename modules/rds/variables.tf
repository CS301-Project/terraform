variable "name"              { type = string }                  # e.g. "crm-db"
variable "vpc_id"            { type = string }                  # module.vpc.vpc_id
variable "subnet_ids"        { type = list(string) }            # two public subnets for staging
variable "db_username"       { type = string }                  # e.g. "admin"
variable "db_password"       { 
  type = string 
  sensitive = true 
  }
variable "db_name"           { 
  type = string
  default = "crmdb" 
  }
variable "instance_class"    { 
  type = string
  default = "db.t3.micro" 
  }
variable "allocated_storage" { 
  type = number 
  default = 20 
  }
variable "tags"              {
   type = map(string) 
   default = {} 
   }
