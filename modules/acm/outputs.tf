output "certificate_arn" {
  description = "ARN of the validated ACM certificate in us-east-1"
  value       = aws_acm_certificate.this.arn
}