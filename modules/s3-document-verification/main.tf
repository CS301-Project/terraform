resource "aws_s3_bucket" "document_verification" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_ownership_controls" "document_verification" {
  bucket = aws_s3_bucket.document_verification.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_public_access_block" "document_verification" {
  bucket                  = aws_s3_bucket.document_verification.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy to allow public read access to upload forms
resource "aws_s3_bucket_policy" "document_verification" {
  bucket = aws_s3_bucket.document_verification.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadUploadForms"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.document_verification.arn}/upload-forms/*"
      }
    ]
  })
}

resource "aws_s3_bucket_versioning" "document_verification" {
  bucket = aws_s3_bucket.document_verification.id
  versioning_configuration { status = var.enable_versioning ? "Enabled" : "Suspended" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "document_verification" {
  bucket = aws_s3_bucket.document_verification.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# CORS configuration for presigned URL uploads
resource "aws_s3_bucket_cors_configuration" "document_verification" {
  bucket = aws_s3_bucket.document_verification.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = var.allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# S3 bucket notification to trigger Lambda on object creation
resource "aws_s3_bucket_notification" "document_verification" {
  bucket = aws_s3_bucket.document_verification.id

  lambda_function {
    lambda_function_arn = var.document_ingest_lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.filter_prefix
    filter_suffix       = var.filter_suffix
  }

  depends_on = [var.lambda_permission_id]
}
