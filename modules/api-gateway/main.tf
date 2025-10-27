resource "aws_api_gateway_rest_api" "logs_api" {
  name        = "audit-logs-api"
  description = "API for reading audit logs"
}

resource "aws_api_gateway_resource" "logs" {
  rest_api_id = aws_api_gateway_rest_api.logs_api.id
  parent_id   = aws_api_gateway_rest_api.logs_api.root_resource_id
  path_part   = "logs"
}

resource "aws_api_gateway_method" "get_logs" {
  rest_api_id   = aws_api_gateway_rest_api.logs_api.id
  resource_id   = aws_api_gateway_resource.logs.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.logs_api.id
  resource_id = aws_api_gateway_resource.logs.id
  http_method = aws_api_gateway_method.get_logs.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.read_lambda_invoke_arn
}

resource "aws_api_gateway_deployment" "logs_api_deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]

  rest_api_id = aws_api_gateway_rest_api.logs_api.id
}

resource "aws_api_gateway_stage" "logs_api_stage" {
  deployment_id = aws_api_gateway_deployment.logs_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.logs_api.id
  stage_name    = "prod"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.read_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.logs_api.execution_arn}/*/*"
}