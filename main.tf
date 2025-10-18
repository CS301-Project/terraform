module "vpc" {
  source = "./modules/vpc"
}

module "network_acls" {
  source = "./modules/network_acls"
  vpc_id = module.vpc.vpc_id
}

module "network_acl_associations" {
  source                = "./modules/associations"
  db_acl_id             = module.network_acls.db_acl_id
  ecs_acl_id            = module.network_acls.ecs_acl_id
  ecs_az1_subnet_id     = module.vpc.ecs_az1_subnet_id
  ecs_az2_subnet_id     = module.vpc.ecs_az2_subnet_id
  rds_primary_subnet_id = module.vpc.rds_primary_subnet_id
  rds_backup_subnet_id  = module.vpc.rds_backup_subnet_id
}

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