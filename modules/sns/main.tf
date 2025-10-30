resource "aws_sns_topic" "textract_completion" {
  name              = var.topic_name
  display_name      = "Textract Document Analysis Completion"
  kms_master_key_id = var.enable_encryption ? aws_kms_key.sns[0].id : null

  tags = {
    Name        = var.topic_name
    Environment = "production"
  }
}

# KMS key for SNS encryption (optional)
resource "aws_kms_key" "sns" {
  count                   = var.enable_encryption ? 1 : 0
  description             = "KMS key for SNS topic encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "${var.topic_name}-kms"
    Environment = "production"
  }
}

resource "aws_kms_alias" "sns" {
  count         = var.enable_encryption ? 1 : 0
  name          = "alias/${var.topic_name}-kms"
  target_key_id = aws_kms_key.sns[0].key_id
}

# SNS Topic Policy to allow Textract to publish
resource "aws_sns_topic_policy" "textract_completion" {
  arn = aws_sns_topic.textract_completion.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTextractPublish"
        Effect = "Allow"
        Principal = {
          Service = "textract.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.textract_completion.arn
      },
      {
        Sid    = "AllowLambdaSubscribe"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "SNS:Subscribe",
          "SNS:Receive"
        ]
        Resource = aws_sns_topic.textract_completion.arn
      }
    ]
  })
}
