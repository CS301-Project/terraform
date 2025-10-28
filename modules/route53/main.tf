data "aws_route53_zone" "primary" {
  name         = "itsag3t2.com"
  private_zone = false
}

locals {
  cloudfront_zone_id = "Z2FDTNDATAQYW2"
}

resource "aws_route53_record" "app_a" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.record_name
  type    = "A"
  alias {
    name                   = var.cloudfront_domain_name   
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }

#Won't destroy this by accident
  lifecycle { prevent_destroy = true }
}

# AAAA (ALIAS) -> CloudFront
resource "aws_route53_record" "app_aaaa" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.record_name
  type    = "AAAA"
  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
  lifecycle { prevent_destroy = true }
}
