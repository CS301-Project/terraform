resource "aws_iam_role" "lambda_role" {
  name = "${var.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  
  lifecycle { create_before_destroy = true }

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  depends_on = [aws_iam_role.lambda_role] # ensure role exists before attach

}

resource "aws_lambda_function" "fn" {
  function_name = var.name
  role          = aws_iam_role.lambda_role.arn
  handler       = "com.example.SftpFetchHandler::handleRequest"
  runtime       = "java21"
  memory_size   = 512
  timeout       = 60

  filename         = "${path.module}/artifact/sftp-fetch.jar"
  source_code_hash = filebase64sha256("${path.module}/artifact/sftp-fetch.jar")

  # Lambda OUTSIDE VPC (no vpc_config)

  environment {
    variables = {
      # SFTP
      SFTP_HOST     = var.sftp_host
      SFTP_PORT     = tostring(var.sftp_port)
      SFTP_USER     = var.sftp_user
      SFTP_PASSWORD = var.sftp_password
      SFTP_DIR      = "/upload/incoming"

      # DB
      DB_URL      = "jdbc:mysql://${var.db_endpoint}:${var.db_port}/${var.db_name}"
      DB_USER     = var.db_user
      DB_PASSWORD = var.db_password
    }
  }

  tags = var.tags
}

# (Optional) Schedule every 15 minutes
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
