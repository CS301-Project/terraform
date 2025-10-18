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
  rds_primary_subnet_id = module.vpc.rds_primary_subnet_id
  rds_backup_subnet_id  = module.vpc.rds_backup_subnet_id
}