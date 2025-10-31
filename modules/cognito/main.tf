# Get current AWS region
data "aws_region" "current" {}

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = var.user_pool_name

  # Allow email as sign-in attribute
  username_attributes = ["email"]

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
  name                = var.user_pool_client_name
  user_pool_id        = aws_cognito_user_pool.main.id
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
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
  name             = "root_admin"
  user_pool_id     = aws_cognito_user_pool.main.id
  description      = "Root admin group with full system access"
  precedence       = 0
}

resource "aws_cognito_user_group" "admin" {
  name             = "admin"
  user_pool_id     = aws_cognito_user_pool.main.id
  description      = "Admin group with administrative access"
  precedence       = 1
}

resource "aws_cognito_user_group" "agent" {
  name             = "agent"
  user_pool_id     = aws_cognito_user_pool.main.id
  description      = "Agent group for standard user access"
  precedence       = 2
}

#initialise root_admin with permanent password
resource "aws_cognito_user" "root_admin" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = var.root_admin_email  # Use email as username since pool is configured for email sign-in

  attributes = {
    email          = var.root_admin_email
    email_verified = "true"
  }

  # Suppress welcome email since this is a system account
  message_action = "SUPPRESS"
}

# Add root_admin user to root_admin group
resource "aws_cognito_user_in_group" "root_admin" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = aws_cognito_user.root_admin.username
  group_name   = aws_cognito_user_group.root_admin.name
}

# Set permanent password for root_admin using null_resource + local-exec (AWS CLI)
resource "null_resource" "root_admin_set_password" {
  depends_on = [
    aws_cognito_user.root_admin,
    aws_cognito_user_in_group.root_admin
  ]

  triggers = {
    user_id  = aws_cognito_user.root_admin.id
    password = random_password.root_admin_permanent.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws cognito-idp admin-set-user-password \
        --user-pool-id '${aws_cognito_user_pool.main.id}' \
        --username '${aws_cognito_user.root_admin.username}' \
        --password '${random_password.root_admin_permanent.result}' \
        --permanent \
        --region '${data.aws_region.current.name}'
    EOT
  }
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
    username     = aws_cognito_user.root_admin.username
    password     = random_password.root_admin_permanent.result
    user_pool_id = aws_cognito_user_pool.main.id
    email        = var.root_admin_email
    instructions = "Use password to login directly - no password change required"
  })
}

resource "random_password" "root_admin_permanent" {
  length  = 20
  special = true
}