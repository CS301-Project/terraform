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