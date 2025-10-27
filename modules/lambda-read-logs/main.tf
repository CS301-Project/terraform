data "archive_file" "lambda_read_logs" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "read_logs" {
  filename         = data.archive_file.lambda_read_logs.output_path
  function_name    = "audit-logs-read"
  role            = aws_iam_role.lambda_read_logs.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_read_logs.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.logs_table_name
    }
  }
}

resource "aws_iam_role" "lambda_read_logs" {
  name = "lambda-read-logs-role"

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
}

resource "aws_iam_role_policy" "lambda_read_logs_dynamodb" {
  name = "lambda-read-logs-dynamodb-policy"
  role = aws_iam_role.lambda_read_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:GetItem"
        ]
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_read_logs_basic" {
  role       = aws_iam_role.lambda_read_logs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda_read_logs" {
  name              = "/aws/lambda/${aws_lambda_function.read_logs.function_name}"
  retention_in_days = 7
}