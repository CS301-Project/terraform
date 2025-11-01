# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = var.user_pool_name

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Account recovery settings
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User attributes to auto-verify
  auto_verified_attributes = ["email"]

  tags = {
    Name        = var.user_pool_name
    Environment = var.environment
  }
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "main" {
  name         = var.user_pool_client_name
  user_pool_id = aws_cognito_user_pool.main.id
  explicit_auth_flows = [
    "ALLOW_USER_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH"
  ]

  # Token expiration
  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30
  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"
}

# Cognito User Pool Domain (required for OAuth flows)
resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.user_pool_domain
  user_pool_id = aws_cognito_user_pool.main.id
}

# Cognito User Groups
resource "aws_cognito_user_group" "root_admin" {
  name         = "root_admin"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Root admin group with full system access"
  precedence   = 0
}

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Admin group with administrative access"
  precedence   = 1
}

resource "aws_cognito_user_group" "agent" {
  name         = "agent"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Agent group for standard user access"
  precedence   = 2
}

#initialise root_admin
resource "aws_cognito_user" "root_admin" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = "root_admin"

  attributes = {
    email          = var.root_admin_email
    email_verified = "true"
  }

  # Set temporary password - forces change on first login
  temporary_password = random_password.root_admin_temp.result

  # Suppress welcome email since this is a system account
  message_action = "SUPPRESS"
}

# Create secret for root_admin credentials
resource "aws_secretsmanager_secret" "root_admin_credentials" {
  name                    = "cognito/root-admin-credentials"
  description             = "Root admin user credentials for Cognito User Pool"
  recovery_window_in_days = 7

  tags = {
    Name        = "root-admin-credentials"
    Environment = var.environment
  }
}

# Store credentials in Secrets Manager
resource "aws_secretsmanager_secret_version" "root_admin_credentials" {
  secret_id = aws_secretsmanager_secret.root_admin_credentials.id
  secret_string = jsonencode({
    username           = aws_cognito_user.root_admin.username
    temporary_password = random_password.root_admin_temp.result
    user_pool_id       = aws_cognito_user_pool.main.id
    email              = var.root_admin_email
    instructions       = "Use temporary_password to login, then set new password when prompted"
  })
}

resource "random_password" "root_admin_temp" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()-_=+"
  upper            = true
  lower            = true
}