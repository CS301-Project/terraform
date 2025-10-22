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
