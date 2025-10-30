resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_policy" "ecs_secrets_access" {
  name = "ecs-secrets-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          var.account_db_secret_arn,
          var.client_db_secret_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          var.rds_kms_key_arn
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_secrets_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.ecs_secrets_access.arn
}

resource "aws_iam_policy" "ecs_task_logging_sqs_policy" {
  name = "ecs-task-sqs-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          var.sqs_logging_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role_client" {
  name = "ecs-task-role-client"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_client_logging_sqs_attach" {
  role       = aws_iam_role.ecs_task_role_client.name
  policy_arn = aws_iam_policy.ecs_task_logging_sqs_policy.arn
}

# Additional policy for Client ECS to access verification queues
resource "aws_iam_policy" "ecs_task_verification_sqs_policy" {
  name = "ecs-task-verification-sqs-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          var.verification_request_queue_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          var.verification_results_queue_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_client_verification_sqs_attach" {
  role       = aws_iam_role.ecs_task_role_client.name
  policy_arn = aws_iam_policy.ecs_task_verification_sqs_policy.arn
}

resource "aws_iam_role" "ecs_task_role_account" {
  name = "ecs-task-role-account"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

}

resource "aws_iam_role_policy_attachment" "ecs_task_account_logging_sqs_attach" {
  role       = aws_iam_role.ecs_task_role_account.name
  policy_arn = aws_iam_policy.ecs_task_logging_sqs_policy.arn
}