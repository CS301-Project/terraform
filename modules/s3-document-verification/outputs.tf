output "bucket_name" {
  description = "Name of the document verification S3 bucket"
  value       = aws_s3_bucket.document_verification.bucket
}

output "bucket_arn" {
  description = "ARN of the document verification S3 bucket"
  value       = aws_s3_bucket.document_verification.arn
}

output "bucket_id" {
  description = "ID of the document verification S3 bucket"
  value       = aws_s3_bucket.document_verification.id
}

output "bucket_domain_name" {
  description = "Domain name of the document verification S3 bucket"
  value       = aws_s3_bucket.document_verification.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the document verification S3 bucket"
  value       = aws_s3_bucket.document_verification.bucket_regional_domain_name
}
