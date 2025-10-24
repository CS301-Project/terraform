module "vpc" {
  source             = "./modules/vpc"
  aws_region         = "ap-southeast-1"
  vpc_endpoint_sg_id = module.security_groups.vpc_endpoint_sg_id
}

# module "network_acls" {
#   source = "./modules/network_acls"
#   vpc_id = module.vpc.vpc_id
# }

# module "network_acl_associations" {
#   source                = "./modules/associations"
#   db_acl_id             = module.network_acls.db_acl_id
#   ecs_acl_id            = module.network_acls.ecs_acl_id
#   ecs_az1_subnet_id     = module.vpc.ecs_az1_subnet_id
#   ecs_az2_subnet_id     = module.vpc.ecs_az2_subnet_id
#   rds_primary_subnet_id = module.vpc.rds_primary_subnet_id
#   rds_backup_subnet_id  = module.vpc.rds_backup_subnet_id
# }

module "rds" {
  source = "./modules/rds"
  rds_subnet_ids = [
    module.vpc.rds_primary_subnet_id,
    module.vpc.rds_backup_subnet_id
  ]
  transaction_rds_permitted_sgs = [
    module.security_groups.allow_transaction_lambda_to_transaction_rds_sg_id
  ]
  client_rds_permitted_sgs = [
    module.security_groups.allow_client_ecs_to_client_rds_sg_id
  ]
  account_rds_permitted_sgs = [
    module.security_groups.allow_account_ecs_to_account_rds_sg_id
  ]
}

module "elasticache" {
  source = "./modules/elasticache"
  cache_subnet_ids = [
    module.vpc.rds_primary_subnet_id,
    module.vpc.rds_backup_subnet_id
  ]
  client_cache_sg_ids = [
    module.security_groups.client_ecs_sg_id
  ]
  account_cache_sg_ids = [
    module.security_groups.account_ecs_sg_id
  ]
}

module "security_groups" {
  source = "./modules/security_groups"
  vpc_id = module.vpc.vpc_id
}

# Logging Infrastructure
module "dynamodb" {
  source = "./modules/dynamodb"
}

module "sqs" {
  source = "./modules/sqs"
}

module "lambda_logging" {
  source             = "./modules/lambda-logging"
  logs_table_name    = module.dynamodb.logs_table_name
  dynamodb_table_arn = module.dynamodb.logs_table_arn
  sqs_queue_arn      = module.sqs.logging_queue_arn
  subnet_ids = [
    module.vpc.ecs_az1_subnet_id,
    module.vpc.ecs_az2_subnet_id
  ]
  security_group_ids = [
    module.security_groups.lambda_logging_sg_id
  ]
}

module "network" {
  source               = "./modules/network"
  vpc_id               = module.vpc.vpc_id
  public_subnet_az1_id = module.vpc.public_subnet_az1_id
  public_subnet_az2_id = module.vpc.public_subnet_az2_id
}

module "alb" {
  source = "./modules/alb"
  assigned_sg_ids = [
    module.security_groups.alb_sg_id
  ]
  public_subnet_ids = [
    module.vpc.public_subnet_az1_id,
    module.vpc.public_subnet_az2_id
  ]
  vpc_id = module.vpc.vpc_id
}

module "ecs_cluster" {
  source            = "./modules/ecs_cluster"
  account_ecs_sg_id = module.security_groups.account_ecs_sg_id
  client_ecs_sg_id  = module.security_groups.client_ecs_sg_id
  ecs_private_subnet_ids = [
    module.vpc.ecs_az1_subnet_id,
    module.vpc.ecs_az2_subnet_id
  ]
  account_alb_target_group_arn = module.alb.account_alb_target_group_arn
  client_alb_target_group_arn  = module.alb.client_alb_target_group_arn
  ecs_instance_profile_name    = module.iam.ecs_instance_profile_name
}

module "iam" {
  source = "./modules/iam"
}

# --- ACM certificate in us-east-1 for CloudFront (DNS validation in your hosted zone) ---
# data "aws_route53_zone" "primary" {
#   zone_id = var.hosted_zone_id
# }

# #resource "aws_acm_certificate" "cf" {
#  provider                  = aws.use1
#  domain_name               = var.domain_name
#  subject_alternative_names = var.alternate_names
#  validation_method         = "DNS"
#  lifecycle { create_before_destroy = true }
#}

# resource "aws_route53_record" "cert_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.cf.domain_validation_options : dvo.domain_name => {
#       name    = dvo.resource_record_name
#       value   = dvo.resource_record_value
#       type    = dvo.resource_record_type
#       zone_id = data.aws_route53_zone.primary.zone_id
#     }
#   }

#   name    = each.value.name
#   type    = each.value.type
#   records = [each.value.value]
#   ttl     = 60
#   zone_id = each.value.zone_id
# }

# resource "aws_acm_certificate_validation" "cf" {
#   provider                = aws.use1
#   certificate_arn         = aws_acm_certificate.cf.arn
#   validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
# }

# --- WAF (global / CLOUDFRONT scope) ---
module "waf" {
  source    = "./modules/waf"
  providers = { aws = aws.use1 }

  name                = "${var.project_name}-cf-waf"
  enable_rate_limit   = true
  rate_limit_requests = 1000
}

# --- S3 frontend bucket (private; OAC-only access) ---
module "s3_frontend" {
  source = "./modules/s3_frontend"

  bucket_name       = var.frontend_bucket_name
  enable_versioning = true
  force_destroy     = false
  # This will be populated when CF is created in the same plan
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
}

# --- CloudFront distribution (S3 origin + optional ALB /api/*) ---
module "cloudfront" {
  source = "./modules/cloudfront"

  name                = "${var.project_name}-cf"
  aliases             = [] # e.g., ["app.example.com"]
  use_default_certificate = true
  web_acl_arn         = module.waf.web_acl_arn

  s3_bucket_name   = module.s3_frontend.bucket_name
  s3_bucket_region = var.region

  price_class = "PriceClass_100"

  # Optional: route /api/* to your ALB backend
  enable_api_behavior          = var.enable_api_behavior
  api_path_pattern             = var.api_path_pattern
  alb_origin_dns_name          = var.alb_dns_name
  api_origin_request_policy_id = var.api_origin_request_policy_id

  # Optional logging
  log_bucket = var.cf_log_bucket
  log_prefix = "cloudfront/"
}

# Allow CloudFront (via OAC) to read from the S3 bucket
data "aws_iam_policy_document" "frontend_oac" {
  statement {
    sid     = "AllowCloudFrontAccessViaOAC"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = ["${module.s3_frontend.bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront.distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_oac" {
  bucket = module.s3_frontend.bucket_name
  policy = data.aws_iam_policy_document.frontend_oac.json
}


# --- Route53 alias (A/AAAA) to CloudFront ---
# module "route53" {
#   source = "./modules/route53"

#   hosted_zone_id         = var.hosted_zone_id
#   record_name            = var.record_name # e.g., "app.example.com"
#   cloudfront_domain_name = module.cloudfront.domain_name
# }


#VARIABLES might need to move it
variable "project_name" { type = string }
variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "hosted_zone_id" { type = string } # existing Route 53 zone
variable "domain_name" { type = string }    # apex used for ACM, e.g., example.com
variable "alternate_names" {
  type    = list(string)
  default = []
}                                        # e.g., ["app.example.com"]
variable "record_name" { type = string } # e.g., "app.example.com"

variable "frontend_bucket_name" { type = string }

# Optional logging / API
variable "cf_log_bucket" {
  type    = string
  default = ""
} # S3 bucket name (no ARN)
variable "enable_api_behavior" {
  type    = bool
  default = false
}
variable "api_path_pattern" {
  type    = string
  default = "/api/*"
}
variable "alb_dns_name" {
  type    = string
  default = ""
} # from your ALB module output, if used
variable "api_origin_request_policy_id" {
  type    = string
  default = null
}