output "cloudtrail_bucket" {
  description = "S3 bucket storing CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_logs.bucket
}

output "cloudtrail_name" {
  description = "The name of the CloudTrail trail"
  value       = aws_cloudtrail.main.name
}

output "cloudtrail_log_group" {
  description = "CloudWatch log group for CloudTrail logs"
  value       = var.enable_log_group ? aws_cloudwatch_log_group.cloudtrail_logs.name : ""
}
