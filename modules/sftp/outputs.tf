#DEPRECIATED, USING LOCAL SFTP

output "sftp_public_ip" { value = aws_eip.this.public_ip }
output "sftp_username" { value = var.sftp_username }
