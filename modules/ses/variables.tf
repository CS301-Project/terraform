variable "sender_email" {
  description = "Email address to send verification emails from (must be verified in SES)"
  type        = string
}

variable "domain_name" {
  description = "Domain name for SES domain identity (optional, leave empty to use email identity only)"
  type        = string
  default     = ""
}

variable "application_name" {
  description = "Name of the application (used in email templates)"
  type        = string
  default     = "UBSCRM"
}

variable "configuration_set_name" {
  description = "Name of the SES configuration set"
  type        = string
  default     = "verification-config-set"
}

variable "enable_event_tracking" {
  description = "Enable CloudWatch event tracking for email metrics"
  type        = bool
  default     = false
}
