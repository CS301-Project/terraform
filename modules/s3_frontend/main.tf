terraform { required_version = ">= 1.5" }

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration { status = var.enable_versioning ? "Enabled" : "Suspended" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# data "aws_iam_policy_document" "bucket_policy" {
#   dynamic "statement" {
#     for_each = var.cloudfront_distribution_arn == "" ? [] : [1]
#     content {
#       sid     = "AllowCloudFrontAccessViaOAC"
#       effect  = "Allow"
#       actions = ["s3:GetObject"]
#       resources = ["${aws_s3_bucket.this.arn}/*"]

#       principals {
#         type        = "Service"
#         identifiers = ["cloudfront.amazonaws.com"]
#       }

#       condition {
#         test     = "StringEquals"
#         variable = "AWS:SourceArn"
#         values   = [var.cloudfront_distribution_arn]
#       }
#     }
#   }
# }

# resource "aws_s3_bucket_policy" "this" {
#   count  = var.cloudfront_distribution_arn == "" ? 0 : 1
#   bucket = aws_s3_bucket.this.id
#   policy = data.aws_iam_policy_document.bucket_policy.json
# }

