# IAM Role for Lambda
resource "aws_iam_role" "textract_result_lambda" {
  name = "textract-result-lambda-role"

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
resource "aws_iam_policy" "textract_result_lambda_policy" {
  name        = "textract-result-lambda-policy"
  description = "Policy for Textract Result Lambda"

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
          "textract:GetDocumentAnalysis",
          "textract:GetDocumentTextDetection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl"
        ]
        Resource = var.verification_results_queue_arn
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

resource "aws_iam_role_policy_attachment" "textract_result_lambda_policy_attach" {
  role       = aws_iam_role.textract_result_lambda.name
  policy_arn = aws_iam_policy.textract_result_lambda_policy.arn
}

# Lambda Function
data "archive_file" "textract_result_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "textract_result" {
  filename         = data.archive_file.textract_result_lambda_zip.output_path
  function_name    = var.function_name
  role             = aws_iam_role.textract_result_lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.textract_result_lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 120
  memory_size      = 512

  environment {
    variables = {
      VERIFICATION_RESULTS_QUEUE_URL = var.verification_results_queue_url
    }
  }

  tags = {
    Name        = var.function_name
    Environment = "production"
  }
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "textract_result" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.textract_result.arn
}

# Lambda permission for SNS to invoke
resource "aws_lambda_permission" "allow_sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.textract_result.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "textract_result_lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
}
