# --- IAM role ---
resource "aws_iam_role" "lambda_role" {
  name = "${var.name}-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

# Basic logging
resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Store private key securely
resource "aws_ssm_parameter" "sftp_key" {
  name        = "/crm/sftp/private_key"
  type        = "SecureString"              # uses AWS-managed KMS by default
  value       = var.sftp_private_key_pem
  description = "SFTP private key for Lambda"
  tags        = var.tags
}

# Allow Lambda to read the SSM parameter
resource "aws_iam_policy" "ssm_read" {
  name = "${var.name}-ssm-read"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["ssm:GetParameter", "ssm:GetParameters", "kms:Decrypt"],
      Resource = [
        aws_ssm_parameter.sftp_key.arn,
        "arn:aws:kms:*:*:key/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_read_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.ssm_read.arn
}

# --- Lambda function (no VPC config) ---
resource "aws_lambda_function" "fn" {
  function_name = var.name
  role          = aws_iam_role.lambda_role.arn
  handler       = "com.example.SftpFetchHandler::handleRequest"
  runtime       = "java21"
  memory_size   = 512
  timeout       = 60

  filename         = "${path.module}/artifact/sftp-fetch.jar"
  source_code_hash = filebase64sha256("${path.module}/artifact/sftp-fetch.jar")

  # No vpc_config -> runs outside VPC

  environment {
    variables = {
      # SFTP
      SFTP_HOST = var.sftp_host
      SFTP_PORT = tostring(var.sftp_port)
      SFTP_USER = var.sftp_user
      SSM_KEY_P = aws_ssm_parameter.sftp_key.name
      SFTP_DIR  = "/upload/incoming"

      # DB (RDS must be public for this to work)
      DB_URL      = "jdbc:mysql://${var.db_endpoint}:${var.db_port}/${var.db_name}"
      DB_USER     = var.db_user
      DB_PASSWORD = var.db_password
    }
  }

  tags = var.tags
}

# Optional: EventBridge schedule
resource "aws_cloudwatch_event_rule" "every_15m" {
  name                = "${var.name}-schedule-15m"
  schedule_expression = "rate(15 minutes)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "t" {
  rule      = aws_cloudwatch_event_rule.every_15m.name
  target_id = "lambda"
  arn       = aws_lambda_function.fn.arn
}

resource "aws_lambda_permission" "events_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_15m.arn
}
