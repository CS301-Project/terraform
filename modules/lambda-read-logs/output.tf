output "lambda_function_arn" {
  value = aws_lambda_function.read_logs.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.read_logs.function_name
}

output "lambda_invoke_arn" {
  value = aws_lambda_function.read_logs.invoke_arn
}