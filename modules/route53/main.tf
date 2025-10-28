

locals {
  itsag3t2_zone_id   = "Z02476682ZA07ZPCPXK1X" # our hosted zone ID
  cloudfront_zone_id = "Z2FDTNDATAQYW2"        # CloudFront public hosted zone ID
}

# A (ALIAS) -> CloudFront
resource "aws_route53_record" "app_a" {
  zone_id = local.itsag3t2_zone_id
  name    = var.record_name
  type    = "A"
  allow_overwrite = true
  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }

  #lifecycle { prevent_destroy = true }
}

# AAAA (ALIAS) -> CloudFront
resource "aws_route53_record" "app_aaaa" {
  zone_id = local.itsag3t2_zone_id
  name    = var.record_name
  type    = "AAAA"
  allow_overwrite = true
  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }

  #lifecycle { prevent_destroy = true }
}
