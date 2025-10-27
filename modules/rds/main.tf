resource "aws_kms_key" "rds_kms_key" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::200842396352:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow terraform-infra key management"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::200842396352:user/terraform-infra"
        }
        Action = [
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow ECS task execution to decrypt only"
        Effect = "Allow"
        Principal = {
          AWS = var.ecs_task_execution_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow RDS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "rds.ap-southeast-1.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "Allow Secrets Manager to encrypt/decrypt"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "secretsmanager.ap-southeast-1.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_db_subnet_group" "main" {
  name       = "shared-db-subnet-group"
  subnet_ids = var.rds_subnet_ids
}

resource "aws_db_instance" "account_db" {
  identifier                    = "account-db"
  engine                        = "postgres"
  instance_class                = "db.t3.medium"
  multi_az                      = true
  db_subnet_group_name          = aws_db_subnet_group.main.name
  allocated_storage             = 50
  max_allocated_storage         = 100
  username                      = "pgadmin"
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.rds_kms_key.key_id
  skip_final_snapshot           = true
  vpc_security_group_ids        = var.account_rds_permitted_sgs
}

resource "aws_db_instance" "client_db" {
  identifier                    = "client-db"
  engine                        = "postgres"
  instance_class                = "db.t3.medium"
  multi_az                      = true
  db_subnet_group_name          = aws_db_subnet_group.main.name
  allocated_storage             = 50
  max_allocated_storage         = 100
  username                      = "pgadmin"
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.rds_kms_key.key_id
  skip_final_snapshot           = true
  vpc_security_group_ids        = var.client_rds_permitted_sgs
}

resource "aws_db_instance" "transaction_db" {
  identifier                    = "transaction-db"
  engine                        = "postgres"
  instance_class                = "db.t3.medium"
  multi_az                      = true
  db_subnet_group_name          = aws_db_subnet_group.main.name
  allocated_storage             = 50
  max_allocated_storage         = 100
  username                      = "pgadmin"
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.rds_kms_key.key_id
  skip_final_snapshot           = true
  vpc_security_group_ids        = var.transaction_rds_permitted_sgs
}

