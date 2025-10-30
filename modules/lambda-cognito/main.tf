# Package Lambda function with dependencies
data "archive_file" "lambda_cognito" {
  type        = "zip"
  source_dir  = "${path.module}/package"
  output_path = "${path.module}/lambda_function.zip"
  excludes    = ["__pycache__", "*.pyc"]

  depends_on = [null_resource.install_dependencies]
}

# Install Python dependencies
resource "null_resource" "install_dependencies" {
  triggers = {
    requirements = filemd5("${path.module}/requirements.txt")
    source_hash  = sha256(join("", [for f in fileset("${path.module}/src", "**") : filesha256("${path.module}/src/${f}")]))
  }

  provisioner "local-exec" {
    command = <<EOF
      rm -rf ${path.module}/package
      mkdir -p ${path.module}/package
      pip install -r ${path.module}/requirements.txt -t ${path.module}/package --platform manylinux2014_x86_64 --python-version 3.9 --only-binary=:all: --upgrade 
      cp -r ${path.module}/src/* ${path.module}/package/
    EOF
  }
}

# Lambda Function
resource "aws_lambda_function" "cognito_handler" {
  filename         = data.archive_file.lambda_cognito.output_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda_cognito.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_cognito.output_base64sha256
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      COGNITO_USER_POOL_ID    = var.user_pool_id
      COGNITO_CLIENT_ID       = var.client_id
      POWERTOOLS_SERVICE_NAME = "auth-service"
      LOG_LEVEL               = var.log_level
    }
  }

  tags = {
    Name        = var.function_name
    Environment = var.environment
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_cognito" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.function_name}-role"
    Environment = var.environment
  }
}

# IAM Policy for Cognito operations
resource "aws_iam_role_policy" "lambda_cognito_policy" {
  name = "${var.function_name}-cognito-policy"
  role = aws_iam_role.lambda_cognito.id

  policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect = "Allow"
      Action = [
        "cognito-idp:AdminInitiateAuth",
        "cognito-idp:AdminCreateUser",
        "cognito-idp:AdminSetUserPassword",
        "cognito-idp:AdminDeleteUser",
        "cognito-idp:AdminDisableUser",
        "cognito-idp:AdminEnableUser",
        "cognito-idp:AdminUpdateUserAttributes",
        "cognito-idp:AdminGetUser",
        "cognito-idp:AdminResetUserPassword",
        "cognito-idp:ListUsers",
        "cognito-idp:SignUp",
        "cognito-idp:ConfirmSignUp",
        "cognito-idp:InitiateAuth",
        "cognito-idp:RespondToAuthChallenge",
        "cognito-idp:GetUser",
        "cognito-idp:ForgotPassword",
        "cognito-idp:ConfirmForgotPassword",
        "cognito-idp:GlobalSignOut"
      ],
      Resource = "*"
    }
  ]
})
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_cognito_basic" {
  role       = aws_iam_role.lambda_cognito.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_cognito" {
  name              = "/aws/lambda/${aws_lambda_function.cognito_handler.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.function_name}-logs"
    Environment = var.environment
  }
}

#aws lambda permissions
resource "aws_lambda_permission" "allow_cognito_invoke" {
  statement_id  = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cognito_handler.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = var.user_pool_arn
}

