output "verified_email_identities" {
  description = "List of verified email addresses"
  value       = [for identity in aws_ses_email_identity.verified_senders : identity.email]
}

output "verified_email_arns" {
  description = "Map of verified email identities and their ARNs"
  value       = { for k, v in aws_ses_email_identity.verified_senders : k => v.arn }
}

output "domain_identity_arn" {
  description = "ARN of the domain identity (if configured)"
  value       = var.domain_name != "" ? aws_ses_domain_identity.domain[0].arn : null
}

output "template_name" {
  description = "Name of the verification email template"
  value       = aws_ses_template.verification_email.name
}

output "configuration_set_name" {
  description = "Name of the SES configuration set"
  value       = aws_ses_configuration_set.verification.name
}

output "configuration_set_arn" {
  description = "ARN of the SES configuration set"
  value       = aws_ses_configuration_set.verification.arn
}
