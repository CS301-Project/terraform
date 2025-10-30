resource "aws_sqs_queue" "logging_queue_dlq" {
  name                      = "logging-queue-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name        = "logging-queue-dlq"
    Environment = "production"
  }
}

resource "aws_sqs_queue" "logging_queue" {
  name                       = "logging-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.logging_queue_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "logging-queue"
    Environment = "production"
  }
}

resource "aws_sqs_queue_policy" "logging_queue_policy" {
  queue_url = aws_sqs_queue.logging_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "ecs-tasks.amazonaws.com"
          ]
        }
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.logging_queue.arn
      }
    ]
  })
}

# Verification Request Queue (Client ECS -> Email Sender Lambda)
resource "aws_sqs_queue" "verification_request_queue_dlq" {
  name                      = "verification-request-queue-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name        = "verification-request-queue-dlq"
    Environment = "production"
  }
}

resource "aws_sqs_queue" "verification_request_queue" {
  name                       = "verification-request-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.verification_request_queue_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "verification-request-queue"
    Environment = "production"
  }
}

resource "aws_sqs_queue_policy" "verification_request_queue_policy" {
  queue_url = aws_sqs_queue.verification_request_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "ecs-tasks.amazonaws.com"
          ]
        }
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.verification_request_queue.arn
      }
    ]
  })
}

# Verification Results Queue (Textract Result Lambda -> Client ECS)
resource "aws_sqs_queue" "verification_results_queue_dlq" {
  name                      = "verification-results-queue-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name        = "verification-results-queue-dlq"
    Environment = "production"
  }
}

resource "aws_sqs_queue" "verification_results_queue" {
  name                       = "verification-results-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.verification_results_queue_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "verification-results-queue"
    Environment = "production"
  }
}

resource "aws_sqs_queue_policy" "verification_results_queue_policy" {
  queue_url = aws_sqs_queue.verification_results_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "ecs-tasks.amazonaws.com"
          ]
        }
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.verification_results_queue.arn
      }
    ]
  })
}
