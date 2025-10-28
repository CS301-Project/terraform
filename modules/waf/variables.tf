variable "name" {
  type        = string
  description = "Base name for WAF resources and metrics. Use letters, numbers, -, _ only."
  validation {
    condition     = length(regexall("^[A-Za-z0-9_-]+$", var.name)) > 0
    error_message = "var.name must match ^[A-Za-z0-9_-]+$."
  }
}
variable "enable_rate_limit" {
  type    = bool
  default = true
}
variable "rate_limit_requests" {
  type    = number
  default = 1000
}
