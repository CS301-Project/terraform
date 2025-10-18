resource "aws_elasticache_subnet_group" "main" {
  name        = "shared-cache-subnet-group"
  subnet_ids  = var.cache_subnet_ids
  description = "Subnets for ElastiCache"
}

resource "aws_elasticache_cluster" "client_db_cache" {
  cluster_id           = "client-db-cache"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = var.client_cache_sg_ids
  parameter_group_name = "default.redis7"
}

resource "aws_elasticache_cluster" "account_db_cache" {
  cluster_id           = "account-db-cache"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = var.account_cache_sg_ids
  parameter_group_name = "default.redis7"
}