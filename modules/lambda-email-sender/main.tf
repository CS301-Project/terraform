# IAM Role for Lambda
resource "aws_iam_role" "email_sender_lambda" {
  name = "email-sender-lambda-role"

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

# IAM Policy for Lambda
resource "aws_iam_policy" "email_sender_lambda_policy" {
  name        = "email-sender-lambda-policy"
  description = "Policy for Email Sender Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl"
        ]
        Resource = var.logging_queue_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendTemplatedEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "email_sender_lambda_policy_attach" {
  role       = aws_iam_role.email_sender_lambda.name
  policy_arn = aws_iam_policy.email_sender_lambda_policy.arn
}

# Lambda Function
data "archive_file" "email_sender_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "email_sender" {
  filename         = data.archive_file.email_sender_lambda_zip.output_path
  function_name    = var.function_name
  role             = aws_iam_role.email_sender_lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.email_sender_lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      BUCKET_NAME               = var.bucket_name
      SENDER_EMAIL              = var.sender_email
      TEMPLATE_NAME             = var.template_name
      PRESIGNED_URL_EXPIRATION  = var.presigned_url_expiration
      CONFIGURATION_SET         = var.configuration_set
      LOGGING_QUEUE_URL         = var.logging_queue_url
    }
  }

#   vpc_config {
#     subnet_ids         = var.subnet_ids
#     security_group_ids = var.security_group_ids
#   }

  tags = {
    Name        = var.function_name
    Environment = "production"
  }
}

# SQS Event Source Mapping
resource "aws_lambda_event_source_mapping" "email_sender_sqs" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.email_sender.arn
  batch_size       = var.batch_size
  enabled          = true
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "email_sender_lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
}
