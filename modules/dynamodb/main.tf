resource "aws_dynamodb_table" "logs_table" {
  name           = "application-logs"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "log_id"
  range_key      = "datetime"

  attribute {
    name = "log_id"
    type = "S"
  }

  attribute {
    name = "datetime"
    type = "S"
  }

  attribute {
    name = "client_id"
    type = "S"
  }

  attribute {
    name = "agent_id"
    type = "S"
  }

  attribute {
    name = "crud_operation"
    type = "S"
  }

  # GSI for querying by Client ID
  global_secondary_index {
    name            = "ClientIdIndex"
    hash_key        = "client_id"
    range_key       = "datetime"
    projection_type = "ALL"
  }

  # GSI for querying by Agent ID
  global_secondary_index {
    name            = "AgentIdIndex"
    hash_key        = "agent_id"
    range_key       = "datetime"
    projection_type = "ALL"
  }

  # GSI for querying by CRUD operation
  global_secondary_index {
    name            = "CrudOperationIndex"
    hash_key        = "crud_operation"
    range_key       = "datetime"
    projection_type = "ALL"
  }

  tags = {
    Name        = "application-logs"
    Environment = "production"
  }
}
