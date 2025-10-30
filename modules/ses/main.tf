resource "aws_ses_email_identity" "sender" {
  email = var.sender_email
}

# Optional: Domain identity instead of email
resource "aws_ses_domain_identity" "domain" {
  count  = var.domain_name != "" ? 1 : 0
  domain = var.domain_name
}

# Email template for verification emails
resource "aws_ses_template" "verification_email" {
  name    = "verification-email-template"
  subject = "Document Verification Required - ${var.application_name}"
  html    = <<-EOT
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <title>Document Verification</title>
      </head>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #2c3e50;">Document Verification Required</h2>
          <p>Dear Valued Client,</p>
          <p>We need you to upload your verification documents to complete your registration.</p>
          <p>Please click the button below to upload your documents securely:</p>
          <div style="text-align: center; margin: 30px 0;">
            <a href="{{uploadUrl}}" 
               style="background-color: #3498db; color: white; padding: 15px 30px; 
                      text-decoration: none; border-radius: 5px; display: inline-block;">
              Upload Documents
            </a>
          </div>
          <p style="color: #e74c3c; font-weight: bold;">
            This link will expire in {{expirationHours}} hours.
          </p>
          <p style="font-size: 12px; color: #7f8c8d;">
            If you did not request this verification, please ignore this email.
          </p>
          <hr style="border: none; border-top: 1px solid #ecf0f1; margin: 20px 0;">
          <p style="font-size: 12px; color: #95a5a6;">
            © {{year}} ${var.application_name}. All rights reserved.
          </p>
        </div>
      </body>
    </html>
  EOT
  text    = <<-EOT
    Document Verification Required

    Dear Valued Client,

    We need you to upload your verification documents to complete your registration.

    Please use the following link to upload your documents securely:
    {{uploadUrl}}

    IMPORTANT: This link will expire in {{expirationHours}} hours.

    If you did not request this verification, please ignore this email.

    © {{year}} ${var.application_name}. All rights reserved.
  EOT
}

# Configuration set for tracking email metrics (optional)
resource "aws_ses_configuration_set" "verification" {
  name = var.configuration_set_name

  reputation_metrics_enabled = true
}

# Event destination for bounce/complaint tracking (optional)
resource "aws_ses_event_destination" "verification_events" {
  count                  = var.enable_event_tracking ? 1 : 0
  name                   = "verification-events"
  configuration_set_name = aws_ses_configuration_set.verification.name
  enabled                = true
  matching_types         = ["send", "reject", "bounce", "complaint", "delivery"]

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "ses:configuration-set"
    value_source   = "messageTag"
  }
}
