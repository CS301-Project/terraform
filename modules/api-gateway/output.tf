output "api_endpoint" {
  value = "${aws_api_gateway_stage.logs_api_stage.invoke_url}/logs"
}

output "api_id" {
  value = aws_api_gateway_rest_api.logs_api.id
}