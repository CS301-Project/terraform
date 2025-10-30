resource "aws_api_gateway_rest_api" "main_api" {
  name        = "crm-api"
  description = "API for CRM system - logs, auth, and user management"
}

# Cognito Authorizer
resource "aws_api_gateway_authorizer" "cognito" {
  name                    = "cognito-authorizer"
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  identity_source         = "method.request.header.Authorization"
  type                    = "COGNITO_USER_POOLS"
  provider_arns           = [var.user_pool_arn]
}

# =====================================
# Logs Endpoints
# =====================================

resource "aws_api_gateway_resource" "logs" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_rest_api.main_api.root_resource_id
  path_part   = "logs"
}

resource "aws_api_gateway_method" "get_logs" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.logs.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.logs.id
  http_method             = aws_api_gateway_method.get_logs.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.read_lambda_invoke_arn
}

resource "aws_lambda_permission" "api_gateway_logs" {
  statement_id  = "AllowAPIGatewayInvokeLogs"
  action        = "lambda:InvokeFunction"
  function_name = var.read_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main_api.execution_arn}/*/*"
}

# =====================================
# Auth & User Management Endpoints
# =====================================

# /api resource
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_rest_api.main_api.root_resource_id
  path_part   = "api"
}

# /api/users resource
resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "users"
}

# /api/users/disable resource
resource "aws_api_gateway_resource" "users_disable" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_resource.users.id
  path_part   = "disable"
}

# /api/users/enable resource
resource "aws_api_gateway_resource" "users_enable" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_resource.users.id
  path_part   = "enable"
}

# /api/auth resource
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "auth"
}

# /api/auth/login resource
resource "aws_api_gateway_resource" "auth_login" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "login"
}

# /api/auth/refresh resource
resource "aws_api_gateway_resource" "auth_refresh" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "refresh"
}

# /api/auth/logout resource
resource "aws_api_gateway_resource" "auth_logout" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "logout"
}

# /api/auth/forgot-password resource
resource "aws_api_gateway_resource" "auth_forgot_password" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "forgot-password"
}

# /api/auth/confirm-forgot-password resource
resource "aws_api_gateway_resource" "auth_confirm_forgot_password" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "confirm-forgot-password"
}


# =====================================
# User Management Endpoints
# =====================================

# GET /api/users - List users
resource "aws_api_gateway_method" "users_get" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "users_get" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.users.id
  http_method             = aws_api_gateway_method.users_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.cognito_lambda_invoke_arn
}

# POST /api/users - Create user
resource "aws_api_gateway_method" "users_post" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "users_post" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.users.id
  http_method             = aws_api_gateway_method.users_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.cognito_lambda_invoke_arn
}

# PUT /api/users - Update user
resource "aws_api_gateway_method" "users_put" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "users_put" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.users.id
  http_method             = aws_api_gateway_method.users_put.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.cognito_lambda_invoke_arn
}

# POST /api/users/disable - Disable user
resource "aws_api_gateway_method" "users_disable_post" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.users_disable.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "users_disable_post" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.users_disable.id
  http_method             = aws_api_gateway_method.users_disable_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.cognito_lambda_invoke_arn
}

# POST /api/users/enable - Enable user
resource "aws_api_gateway_method" "users_enable_post" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.users_enable.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "users_enable_post" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.users_enable.id
  http_method             = aws_api_gateway_method.users_enable_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.cognito_lambda_invoke_arn
}

# =====================================
# Authentication Endpoints
# =====================================

# POST /api/auth/login - User login
resource "aws_api_gateway_method" "auth_login_post" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.auth_login.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_login" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.auth_login.id
  http_method             = aws_api_gateway_method.auth_login_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.cognito_lambda_invoke_arn
}

# POST /api/auth/refresh - Refresh token
resource "aws_api_gateway_method" "auth_refresh_post" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.auth_refresh.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_refresh" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.auth_refresh.id
  http_method             = aws_api_gateway_method.auth_refresh_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.cognito_lambda_invoke_arn
}

# POST /api/auth/logout - User logout
resource "aws_api_gateway_method" "auth_logout_post" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.auth_logout.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_logout" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.auth_logout.id
  http_method             = aws_api_gateway_method.auth_logout_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.cognito_lambda_invoke_arn
}

# POST /api/auth/forgot-password - Forgot password
resource "aws_api_gateway_method" "auth_forgot_password_post" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.auth_forgot_password.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_forgot_password" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.auth_forgot_password.id
  http_method             = aws_api_gateway_method.auth_forgot_password_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.cognito_lambda_invoke_arn
}

# POST /api/auth/confirm-forgot-password - Confirm forgot password
resource "aws_api_gateway_method" "auth_confirm_forgot_password_post" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.auth_confirm_forgot_password.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_confirm_forgot_password" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.auth_confirm_forgot_password.id
  http_method             = aws_api_gateway_method.auth_confirm_forgot_password_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.cognito_lambda_invoke_arn
}

# =====================================
# CORS OPTIONS Methods
# =====================================

# OPTIONS /api/users
resource "aws_api_gateway_method" "users_options" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "users_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.users_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "users_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.users_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "users_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.users_options.http_method
  status_code = aws_api_gateway_method_response.users_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.users_options]
}

# OPTIONS /api/users/disable
resource "aws_api_gateway_method" "users_disable_options" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.users_disable.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "users_disable_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.users_disable.id
  http_method = aws_api_gateway_method.users_disable_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "users_disable_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.users_disable.id
  http_method = aws_api_gateway_method.users_disable_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "users_disable_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.users_disable.id
  http_method = aws_api_gateway_method.users_disable_options.http_method
  status_code = aws_api_gateway_method_response.users_disable_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.users_disable_options]
}

# OPTIONS /api/users/enable
resource "aws_api_gateway_method" "users_enable_options" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.users_enable.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "users_enable_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.users_enable.id
  http_method = aws_api_gateway_method.users_enable_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "users_enable_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.users_enable.id
  http_method = aws_api_gateway_method.users_enable_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "users_enable_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.users_enable.id
  http_method = aws_api_gateway_method.users_enable_options.http_method
  status_code = aws_api_gateway_method_response.users_enable_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.users_enable_options]
}

# OPTIONS /api/auth/login
resource "aws_api_gateway_method" "auth_login_options" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.auth_login.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_login_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_login.id
  http_method = aws_api_gateway_method.auth_login_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "auth_login_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_login.id
  http_method = aws_api_gateway_method.auth_login_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "auth_login_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_login.id
  http_method = aws_api_gateway_method.auth_login_options.http_method
  status_code = aws_api_gateway_method_response.auth_login_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.auth_login_options]
}

# OPTIONS /api/auth/refresh
resource "aws_api_gateway_method" "auth_refresh_options" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.auth_refresh.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_refresh_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_refresh.id
  http_method = aws_api_gateway_method.auth_refresh_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "auth_refresh_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_refresh.id
  http_method = aws_api_gateway_method.auth_refresh_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "auth_refresh_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_refresh.id
  http_method = aws_api_gateway_method.auth_refresh_options.http_method
  status_code = aws_api_gateway_method_response.auth_refresh_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.auth_refresh_options]
}

# OPTIONS /api/auth/logout
resource "aws_api_gateway_method" "auth_logout_options" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.auth_logout.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_logout_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_logout.id
  http_method = aws_api_gateway_method.auth_logout_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "auth_logout_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_logout.id
  http_method = aws_api_gateway_method.auth_logout_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "auth_logout_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_logout.id
  http_method = aws_api_gateway_method.auth_logout_options.http_method
  status_code = aws_api_gateway_method_response.auth_logout_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.auth_logout_options]
}

# OPTIONS /api/auth/forgot-password
resource "aws_api_gateway_method" "auth_forgot_password_options" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.auth_forgot_password.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_forgot_password_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_forgot_password.id
  http_method = aws_api_gateway_method.auth_forgot_password_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "auth_forgot_password_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_forgot_password.id
  http_method = aws_api_gateway_method.auth_forgot_password_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "auth_forgot_password_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_forgot_password.id
  http_method = aws_api_gateway_method.auth_forgot_password_options.http_method
  status_code = aws_api_gateway_method_response.auth_forgot_password_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.auth_forgot_password_options]
}

# OPTIONS /api/auth/confirm-forgot-password
resource "aws_api_gateway_method" "auth_confirm_forgot_password_options" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.auth_confirm_forgot_password.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_confirm_forgot_password_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_confirm_forgot_password.id
  http_method = aws_api_gateway_method.auth_confirm_forgot_password_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "auth_confirm_forgot_password_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_confirm_forgot_password.id
  http_method = aws_api_gateway_method.auth_confirm_forgot_password_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "auth_confirm_forgot_password_options" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  resource_id = aws_api_gateway_resource.auth_confirm_forgot_password.id
  http_method = aws_api_gateway_method.auth_confirm_forgot_password_options.http_method
  status_code = aws_api_gateway_method_response.auth_confirm_forgot_password_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.auth_confirm_forgot_password_options]
}

# =====================================
# API Deployment (All Endpoints)
# =====================================

resource "aws_api_gateway_deployment" "main_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.users_get,
    aws_api_gateway_integration.users_post,
    aws_api_gateway_integration.users_put,
    aws_api_gateway_integration.users_disable_post,
    aws_api_gateway_integration.users_enable_post,
    aws_api_gateway_integration.auth_login,
    aws_api_gateway_integration.auth_refresh,
    aws_api_gateway_integration.auth_logout,
    aws_api_gateway_integration.auth_forgot_password,
    aws_api_gateway_integration.auth_confirm_forgot_password,
    aws_api_gateway_integration_response.users_options,
    aws_api_gateway_integration_response.users_disable_options,
    aws_api_gateway_integration_response.users_enable_options,
    aws_api_gateway_integration_response.auth_login_options,
    aws_api_gateway_integration_response.auth_refresh_options,
    aws_api_gateway_integration_response.auth_logout_options,
    aws_api_gateway_integration_response.auth_forgot_password_options,
    aws_api_gateway_integration_response.auth_confirm_forgot_password_options
  ]

  rest_api_id = aws_api_gateway_rest_api.main_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.lambda_integration,
      aws_api_gateway_integration.users_get,
      aws_api_gateway_integration.users_post,
      aws_api_gateway_integration.users_put,
      aws_api_gateway_integration.users_disable_post,
      aws_api_gateway_integration.users_enable_post,
      aws_api_gateway_integration.auth_login,
      aws_api_gateway_integration.auth_refresh,
      aws_api_gateway_integration.auth_logout,
      aws_api_gateway_integration.auth_forgot_password,
      aws_api_gateway_integration.auth_confirm_forgot_password
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main_stage" {
  deployment_id = aws_api_gateway_deployment.main_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  stage_name    = "prod"
}

# Lambda permission for Cognito Lambda
resource "aws_lambda_permission" "api_gateway_cognito" {
  statement_id  = "AllowAPIGatewayInvokeCognito"
  action        = "lambda:InvokeFunction"
  function_name = var.cognito_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main_api.execution_arn}/*/*"
}