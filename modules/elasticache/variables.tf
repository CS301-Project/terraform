variable "cache_subnet_ids" {
  description = "List of subnet IDs for ElastiCache"
  type        = list(string)
}

variable "client_cache_sg_ids" {
  description = "Security Group ID for the client Redis cache"
  type        = list(string)
}

variable "account_cache_sg_ids" {
  description = "Security Group ID for the account Redis cache"
  type        = list(string)
}
