data "aws_kms_key" "rds_secret_key" {
  key_id = "arn:aws:kms:ap-southeast-1:200842396352:key/d6365c7b-9ba5-4cd1-830f-2919d233f3d6"
}

resource "aws_db_subnet_group" "main" {
  name = "shared-db-subnet-group"
  subnet_ids = [
    var.rds_primary_subnet_id,
    var.rds_backup_subnet_id
  ]
}

resource "aws_db_instance" "account_db" {
  identifier           = "account-db"
  engine               = "postgres"
  instance_class       = "db.t3.medium"
  multi_az             = true
  db_subnet_group_name = aws_db_subnet_group.main.name
  allocated_storage     = 50
  max_allocated_storage = 100
  username = "pgadmin"
  manage_master_user_password = true
  master_user_secret_kms_key_id = data.aws_kms_key.rds_secret_key.key_id
  skip_final_snapshot = true

}

resource "aws_db_instance" "client_db" {
  identifier           = "client-db"
  engine               = "postgres"
  instance_class       = "db.t3.medium"
  multi_az             = true
  db_subnet_group_name = aws_db_subnet_group.main.name
  allocated_storage     = 50
  max_allocated_storage = 100
  username = "pgadmin"
  manage_master_user_password = true
  master_user_secret_kms_key_id = data.aws_kms_key.rds_secret_key.key_id
  skip_final_snapshot = true

}

resource "aws_db_instance" "transaction_db" {
  identifier           = "transaction-db"
  engine               = "postgres"
  instance_class       = "db.t3.medium"
  multi_az             = true
  db_subnet_group_name = aws_db_subnet_group.main.name
  allocated_storage     = 50
  max_allocated_storage = 100
  username = "pgadmin"
  manage_master_user_password = true
  master_user_secret_kms_key_id = data.aws_kms_key.rds_secret_key.key_id
  skip_final_snapshot = true
}

