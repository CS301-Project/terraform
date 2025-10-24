terraform {
  required_version = ">= 1.5"
}
# Cert selection
variable "use_default_certificate" {
  type    = bool
  default = true
  description = "When true, uses CloudFront default cert and skips ACM; when false, requires acm_certificate_arn."
}