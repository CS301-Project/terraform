# Bubble up module outputs so `terraform output` can see them
output "sftp_public_ip" {
  value = module.sftp.sftp_public_ip
}

output "lambda_name" {
  value = module.lambda_sftp_fetch.lambda_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}
