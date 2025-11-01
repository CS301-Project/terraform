# IAM Role for Lambda
resource "aws_iam_role" "document_ingest_lambda" {
  name = "document-ingest-lambda-role"

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

# IAM Role for Textract to publish to SNS
resource "aws_iam_role" "textract_sns_role" {
  name = "textract-sns-publish-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "textract.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "textract_sns_policy" {
  name        = "textract-sns-publish-policy"
  description = "Allow Textract to publish to SNS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "textract_sns_policy_attach" {
  role       = aws_iam_role.textract_sns_role.name
  policy_arn = aws_iam_policy.textract_sns_policy.arn
}

# IAM Policy for Lambda
resource "aws_iam_policy" "document_ingest_lambda_policy" {
  name        = "document-ingest-lambda-policy"
  description = "Policy for Document Ingest Lambda"

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
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "textract:StartDocumentAnalysis",
          "textract:AnalyzeDocument",
          "textract:GetDocumentAnalysis"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.textract_sns_role.arn
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

resource "aws_iam_role_policy_attachment" "document_ingest_lambda_policy_attach" {
  role       = aws_iam_role.document_ingest_lambda.name
  policy_arn = aws_iam_policy.document_ingest_lambda_policy.arn
}

# Lambda Function
data "archive_file" "document_ingest_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "document_ingest" {
  filename         = data.archive_file.document_ingest_lambda_zip.output_path
  function_name    = var.function_name
  role             = aws_iam_role.document_ingest_lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.document_ingest_lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
      SNS_ROLE_ARN  = aws_iam_role.textract_sns_role.arn
    }
  }

  tags = {
    Name        = var.function_name
    Environment = "production"
  }
}

# Lambda permission for S3 to invoke
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.document_ingest.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.s3_bucket_arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "document_ingest_lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
}
