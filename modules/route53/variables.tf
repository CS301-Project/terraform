variable "zone_name" {
  description = "Existing public hosted zone name"
  type        = string
  default     = "itsag3t2.com."
}

variable "record_name" {
  description = "FQDN you want to serve (e.g., app.itsag3t2.com or itsag3t2.com)"
  type        = string
  default     = "app.itsag3t2.com"
}

variable "cloudfront_domain_name" {
  description = "Your CloudFront distribution domain (e.g., dxxx.cloudfront.net)"
  type        = string
}
