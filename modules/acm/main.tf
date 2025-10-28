# Force ACM in us-east-1 for CloudFront
provider "aws" {
  region = "us-east-1"
}


locals {
  itsag3t2_zone_id = "Z02476682ZA07ZPCPXK1X" # same hosted zone ID
}

resource "aws_acm_certificate" "this" {
  domain_name               = "itsag3t2.com"
  subject_alternative_names = ["www.itsag3t2.com"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation records in your hosted zone (no data source)
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.itsag3t2_zone_id
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
