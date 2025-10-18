resource "aws_network_acl_association" "ecs_az1_network_acl_association" {
  network_acl_id = var.ecs_acl_id
  subnet_id      = var.ecs_az1_subnet_id
}

resource "aws_network_acl_association" "ecs_az2_network_acl_association" {
  network_acl_id = var.ecs_acl_id
  subnet_id      = var.ecs_az2_subnet_id
}

resource "aws_network_acl_association" "rds_primary_network_acl_association" {
  network_acl_id = var.db_acl_id
  subnet_id      = var.rds_primary_subnet_id
}

resource "aws_network_acl_association" "rds_backup_network_acl_association" {
  network_acl_id = var.db_acl_id
  subnet_id      = var.rds_backup_subnet_id
}