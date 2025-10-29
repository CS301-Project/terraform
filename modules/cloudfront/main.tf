resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.name}-oac"
  description                       = "OAC for S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  cache_opt_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
  cache_dis_id = "b2884449-e4de-46a7-ac36-70bc7f1ddd6d" # CachingDisabled
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = var.name
  default_root_object = var.default_root_object
  aliases             = var.aliases


  origin {
    domain_name              = "${var.s3_bucket_name}.s3.${var.s3_bucket_region}.amazonaws.com"
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  dynamic "origin" {
    for_each = var.alb_origin_dns_name == "" ? [] : [1]
    content {
      domain_name = var.alb_origin_dns_name
      origin_id   = "alb-origin"
      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = local.cache_opt_id
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.enable_api_behavior && var.alb_origin_dns_name != "" ? [1] : []
    content {
      path_pattern             = var.api_path_pattern
      target_origin_id         = "alb-origin"
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods           = ["GET", "HEAD", "OPTIONS"]
      cache_policy_id          = local.cache_dis_id
      origin_request_policy_id = var.api_origin_request_policy_id
    }
  }

  price_class = var.price_class

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  dynamic "viewer_certificate" {
    for_each = var.use_default_certificate ? [1] : []
    content {
      cloudfront_default_certificate = true
      minimum_protocol_version       = "TLSv1.2_2021"
    }
  }

  dynamic "viewer_certificate" {
    for_each = var.use_default_certificate ? [] : [1]
    content {
      acm_certificate_arn      = var.acm_certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1.2_2021"
    }
  }

  web_acl_id = var.web_acl_arn

  dynamic "logging_config" {
    for_each = var.log_bucket == "" ? [] : [1]
    content {
      include_cookies = false
      bucket          = "${var.log_bucket}.s3.amazonaws.com"
      prefix          = var.log_prefix
    }
  }
}

data "aws_iam_policy_document" "frontend_oac" {
  statement {
    sid       = "AllowCloudFrontAccessViaOAC"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.s3_frontend_bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_oac" {
  bucket = var.s3_bucket_name
  policy = data.aws_iam_policy_document.frontend_oac.json
}