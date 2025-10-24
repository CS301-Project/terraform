variable "bucket_name"       { type = string }
variable "enable_versioning" { 
  type = bool  
  default = true 
  }
variable "force_destroy"     { 
  type = bool  
  default = false 
  }
variable "cloudfront_distribution_arn" {
  type        = string
  default     = ""
  description = "If set, attaches a bucket policy that grants GET to this CF distribution via OAC."
}

