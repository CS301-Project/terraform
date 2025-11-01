output "api_invoke_url" {
  value       = aws_api_gateway_stage.main_stage.invoke_url
  description = "The base invoke URL for the API"
}

output "api_id" {
  value       = aws_api_gateway_rest_api.main_api.id
  description = "The ID of the API Gateway REST API"
}