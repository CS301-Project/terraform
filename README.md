# Using this command to target the cloudfront & S3 things:
```terraform apply "-target=module.cloudfront" "-target=module.s3_frontend" "-target=aws_s3_bucket_policy.frontend_oac"```
# Then apply WAF:
```terraform apply -target=module.waf```
