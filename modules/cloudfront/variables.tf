variable "name"                { type = string }
variable "aliases"             { 
    type = list(string) 
    default = [] 
}
variable "web_acl_arn"         { 
    type = string 
    default = null 
}

variable "s3_bucket_name"   { type = string }
variable "s3_bucket_region" { type = string }

variable "default_root_object" { 
    type = string 
    default = "index.html" 
}
variable "price_class"         { 
    type = string 
    default = "PriceClass_100" 
}

variable "log_bucket" { 
    type = string 
    default = "" 
    }
variable "log_prefix" { 
    type = string 
    default = "" 
    }

variable "enable_api_behavior"         { 
    type = bool   
default = false 
}
variable "api_path_pattern"            { 
    type = string 
default = "/api/*" 
}
variable "alb_origin_dns_name"         { 
    type = string 
default = "" 
}
variable "api_origin_request_policy_id"{ 
    type = string 
default = null 
}

variable "enable_rate_limit" {
  type    = bool
  default = true
}

variable "rate_limit_requests" {
  type    = number
  default = 1000
}
