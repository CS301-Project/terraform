module "vpc" {
  source                 = "./modules/vpc"
  aws_region             = "ap-southeast-1"
  vpc_endpoint_sg_id     = module.security_groups.vpc_endpoint_sg_id
  private_route_table_id = module.network.private_route_table_id
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
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
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
  source     = "./modules/security_groups"
  vpc_id     = module.vpc.vpc_id
  aws_region = "ap-southeast-1"
  vpc_cidr   = module.vpc.vpc_cidr
  rds_subnet_cidr_blocks = [
    module.vpc.rds_backup_subnet_cidr,
    module.vpc.rds_primary_subnet_cidr
  ]
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

module "lambda_read_logs" {
  source             = "./modules/lambda-read-logs"
  logs_table_name    = module.dynamodb.logs_table_name
  dynamodb_table_arn = module.dynamodb.logs_table_arn
  subnet_ids = [
    module.vpc.ecs_az1_subnet_id,
    module.vpc.ecs_az2_subnet_id
  ]
  security_group_ids = [
    module.security_groups.lambda_logging_sg_id
  ]
}

module "api_gateway" {
  source                     = "./modules/api-gateway"
  read_lambda_invoke_arn     = module.lambda_read_logs.lambda_invoke_arn
  read_lambda_function_name  = module.lambda_read_logs.lambda_function_name
}

module "network" {
  source                    = "./modules/network"
  vpc_id                    = module.vpc.vpc_id
  public_subnet_az1_id      = module.vpc.public_subnet_az1_id
  public_subnet_az2_id      = module.vpc.public_subnet_az2_id
  private_ecs_subnet_az1_id = module.vpc.ecs_az1_subnet_id
  private_ecs_subnet_az2_id = module.vpc.ecs_az2_subnet_id
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
  account_db_endpoint          = module.rds.account_db_endpoint
  client_db_endpoint           = module.rds.client_db_endpoint
  account_db_secret_arn        = module.rds.account_db_secret_arn
  client_db_secret_arn         = module.rds.client_db_secret_arn
  account_db_username          = module.rds.account_db_username
  client_db_username           = module.rds.client_db_username
  client_repository_url        = module.ecr.client_repository_url
  account_repository_url       = module.ecr.account_repository_url
  ecs_task_execution_role_arn  = module.iam.ecs_task_execution_role_arn

}

module "iam" {
  source                = "./modules/iam"
  account_db_secret_arn = module.rds.account_db_secret_arn
  client_db_secret_arn  = module.rds.client_db_secret_arn
  rds_kms_key_arn       = module.rds.rds_secret_key_id
}

module "ecr" {
  source = "./modules/ecr"
}

module "acm" {
  source = "./modules/acm"
}

module "waf" {
  source    = "./modules/waf"
  providers = { aws = aws.use1 }

  name                = "ubscrm-cf-waf"
  enable_rate_limit   = true
  rate_limit_requests = 1000
}

module "s3_frontend" {
  source = "./modules/s3_frontend"

  bucket_name       = "ubscrm-frontend-1"
  enable_versioning = true
  force_destroy     = true
  # This will be populated when CF is created in the same plan
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
}

module "cloudfront" {
  source = "./modules/cloudfront"

  name                    = "ubscrm-cf"
  use_default_certificate = false
  aliases                 = ["itsag3t2.com", "www.itsag3t2.com"]
  acm_certificate_arn     = module.acm.certificate_arn

  web_acl_arn      = module.waf.web_acl_arn
  s3_bucket_name   = module.s3_frontend.bucket_name
  s3_bucket_region = "ap-southeast-1"
  price_class      = "PriceClass_100"

  #route /api/* to your ALB backend
  enable_api_behavior          = false
  api_path_pattern             = "/api/*"
  alb_origin_dns_name          = ""
  api_origin_request_policy_id = null

}

module "route53_apex" {
  source = "./modules/route53"

  # Your module already defaults to zone "itsag3t2.com."
  record_name            = "itsag3t2.com"
  cloudfront_domain_name = module.cloudfront.domain_name
}

module "route53_www" {
  source                 = "./modules/route53"
  record_name            = "www.itsag3t2.com"
  cloudfront_domain_name = module.cloudfront.domain_name
}


data "aws_iam_policy_document" "frontend_oac" {
  statement {
    sid       = "AllowCloudFrontAccessViaOAC"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
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

resource "null_resource" "build_frontend" {
  triggers = {
    # bump this to force a rebuild
    build_version = "1"
  }

  provisioner "local-exec" {
    working_dir = "../frontend"
    command     = "npm ci && npm run build:static" # produces ./out
  }
}

resource "null_resource" "upload_frontend" {
  triggers = {
    build_version = null_resource.build_frontend.triggers.build_version
    bucket        = module.s3_frontend.bucket_name
  }

  depends_on = [null_resource.build_frontend, module.cloudfront, module.s3_frontend]

  provisioner "local-exec" {
    # Run the sync from the out/ folder so paths are simple
    working_dir = "../frontend/out"
    command     = "aws s3 sync . s3://${module.s3_frontend.bucket_name}/ --delete"
  }
}

resource "null_resource" "cf_invalidation" {
  triggers = {
    build_version = null_resource.build_frontend.triggers.build_version
    dist_id       = module.cloudfront.distribution_id
  }

  depends_on = [null_resource.upload_frontend, module.cloudfront]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = "aws cloudfront create-invalidation --distribution-id ${module.cloudfront.distribution_id} --paths '/*'"
  }
}

