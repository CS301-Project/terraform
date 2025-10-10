module "vpc" {
  source               = "./modules/vpc"
  name                 = "crm"
  az_1                 = var.az_1
  az_2                 = var.az_2
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidr   = "10.0.1.0/24"
  public_subnet_cidr_2 = "10.0.2.0/24"
  tags                 = var.tags
}


module "sftp" {
  source           = "./modules/sftp"
  name             = "crm-sftp"
  vpc_id           = module.vpc.vpc_id
  subnet_id        = module.vpc.public_subnet_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
  sftp_username    = "bankhost"
  sftp_user_pubkey = var.sftp_user_pubkey
  instance_type    = "t3.micro" # ~$8–$10/mo in ap-southeast-1
  tags             = var.tags
}
module "lambda_sftp_fetch" {
  source               = "./modules/lambda-sftp-fetch"
  name                 = "crm-sftp-fetcher"

  # SFTP target
  sftp_host            = var.sftp_host            # e.g., module.sftp.sftp_public_ip
  sftp_port            = var.sftp_port
  sftp_user            = var.sftp_user
  sftp_private_key_pem = var.sftp_private_key_pem

  # DB target (from RDS module outputs)
  db_endpoint = module.rds.endpoint
  db_port     = module.rds.port
  db_name     = module.rds.db_name
  db_user     = module.rds.username
  db_password = var.db_password

  tags = var.tags
}


module "rds" {
  source      = "./modules/rds"
  name        = "crm-db"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = [module.vpc.public_subnet_id, module.vpc.public_subnet_id_2]
  db_username = var.db_username
  db_password = var.db_password
  tags        = var.tags
}
