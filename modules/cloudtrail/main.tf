# Get account info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 Bucket for CloudTrail Logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "cloudtrail-logs-${var.env_name}-${data.aws_caller_identity.current.account_id}"

  # lifecycle {
  #   prevent_destroy = true
  # }

  force_destroy = true

  tags = {
    Name        = "cloudtrail-logs-${var.env_name}"
    Environment = var.env_name
  }
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "cloudtrail_logs_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      },
      {
        Sid       = "AWSCloudTrailRead"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_logs.arn
      }
    ]
  })
}

# Enable Versioning
resource "aws_s3_bucket_versioning" "cloudtrail_logs_versioning" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs_sse" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name              = "/aws/cloudtrail/${var.env_name}"
  retention_in_days = 90
}

# IAM Role for CloudTrail
resource "aws_iam_role" "cloudtrail_role" {
  name = "cloudtrail-role-${var.env_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
    }]
  })
}

# Attach the custom CloudTrail full access policy
resource "aws_iam_role_policy_attachment" "cloudtrail_attach" {
  role       = aws_iam_role.cloudtrail_role.name
  policy_arn = aws_iam_policy.cloudtrail_full_access.arn
}

# Custom IAM Policy for CloudTrail Logs Permissions
resource "aws_iam_policy" "cloudtrail_logs_permissions" {
  name        = "CloudTrailLogsPermissions"
  description = "Custom policy for CloudTrail to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/cloudtrail/${var.env_name}:*"
      }
    ]
  })
}

# Attach CloudTrail Logs Permissions to the IAM Role
resource "aws_iam_role_policy_attachment" "cloudtrail_logs_permissions_attach" {
  role       = aws_iam_role.cloudtrail_role.name
  policy_arn = aws_iam_policy.cloudtrail_logs_permissions.arn
}

# CloudTrail
resource "aws_cloudtrail" "main" {
  name                          = "cloudtrail-${var.env_name}"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  cloud_watch_logs_group_arn = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/cloudtrail/${var.env_name}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_role.arn
  depends_on = [
    aws_iam_role_policy_attachment.cloudtrail_attach,
    aws_iam_role_policy_attachment.cloudtrail_logs_permissions_attach
  ]
}

# Optional: Custom IAM Policy for CloudTrail full access
resource "aws_iam_policy" "cloudtrail_full_access" {
  name        = "CloudTrailFullAccessCustom"
  description = "Custom policy for CloudTrail full access and CloudWatch Logs delivery"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudtrail:CreateTrail",
          "cloudtrail:UpdateTrail",
          "cloudtrail:DeleteTrail",
          "cloudtrail:StartLogging",
          "cloudtrail:StopLogging",
          "cloudtrail:DescribeTrails",
          "cloudtrail:LookupEvents",
          "cloudtrail:PutEventSelectors",
          "cloudtrail:GetEventSelectors"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ],
        Resource = ["${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"]
      }
    ]
  })
}
