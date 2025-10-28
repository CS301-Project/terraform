resource "aws_dynamodb_table" "logs_table" {
  name         = "application-logs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "log_id"
  range_key    = "timestamp"

  attribute {
    name = "log_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "service_name"
    type = "S"
  }

  attribute {
    name = "action_type"
    type = "S"
  }

  global_secondary_index {
    name            = "ServiceActionIndex"
    hash_key        = "service_name"
    range_key       = "action_type"
    projection_type = "ALL"
  }

  tags = {
    Name        = "application-logs"
    Environment = "production"
  }
}
