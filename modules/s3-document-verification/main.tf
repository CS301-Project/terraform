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
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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
