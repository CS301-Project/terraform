output "endpoint" { value = aws_db_instance.this.address }
output "port" { value = aws_db_instance.this.port }
output "username" { value = var.db_username }
output "db_name" { value = var.db_name }
