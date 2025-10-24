terraform { required_version = ">= 1.5" }

data "aws_route53_zone" "this" {
  zone_id = var.hosted_zone_id
}

locals { cloudfront_zone_id = "Z2FDTNDATAQYW2" }

resource "aws_route53_record" "a_alias" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = "A"
  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa_alias" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = "AAAA"
  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

