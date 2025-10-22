# Logging System Documentation

This Terraform configuration sets up a centralized logging system using AWS SQS, Lambda, and DynamoDB.

## Architecture

```
Services (ECS/Lambda) → SQS Queue → Lambda Processor → DynamoDB
                           ↓
                      Dead Letter Queue
```

## Components

### 1. **DynamoDB Table** (`modules/dynamodb`)
- Table name: `application-logs`
- Stores all application logs
- Indexes:
  - Primary: `log_id` (hash) + `timestamp` (range)
  - GSI: `service_name` + `action_type`

### 2. **SQS Queues** (`modules/sqs`)
- **Main Queue**: `logging-queue`
  - Receives log messages from all services
  - 4-day message retention
  - 10-second receive wait time
- **Dead Letter Queue**: `logging-queue-dlq`
  - Receives failed messages after 3 attempts
  - 14-day retention

### 3. **Lambda Function** (`modules/lambda-logging`)
- Function name: `log-processor`
- Runtime: Python 3.11
- Triggered by SQS messages
- Processes logs and writes to DynamoDB

### 4. **IAM Roles & Policies** (`modules/iam`)
- ECS task role with SQS send permissions
- Lambda execution role with SQS receive and DynamoDB write permissions

### 5. **Security Groups** (`modules/security_groups`)
- Lambda security group with VPC access

## Usage

After applying this Terraform configuration, you'll get several outputs including:
- `logging_queue_url`: Use this URL to send log messages from your services

### Message Format

Send messages to the SQS queue in this JSON format:

```json
{
  "service_name": "client",
  "action_type": "create",
  "user_id": "user123",
  "resource_id": "resource456",
  "message": "Client profile created successfully",
  "metadata": {
    "email": "user@example.com",
    "additional_info": "..."
  }
}
```

### Service Types
- **client**: Client microservice operations
- **account**: Account microservice operations
- **transaction**: Transaction processing operations

### Action Types
- `create`: Resource creation
- `update`: Resource update
- `delete`: Resource deletion
- `verify`: Verification operations
- `fetch`: Data fetching operations
- `insert`: Data insertion operations

## Integration Examples

See the service-specific examples in the main README for:
- Node.js/Express services (Client & Account)
- Python Lambda functions (Transaction processing)

## Deployment

1. Initialize Terraform:
```bash
terraform init
```

2. Plan the deployment:
```bash
terraform plan
```

3. Apply the configuration:
```bash
terraform apply
```

4. Get the SQS queue URL:
```bash
terraform output logging_queue_url
```

5. Use this URL in your service environment variables as `LOGGING_QUEUE_URL`

## Monitoring

- **Lambda Logs**: CloudWatch log group `/aws/lambda/log-processor`
- **SQS Metrics**: Monitor queue depth and age of oldest message
- **DLQ**: Check for messages that failed processing
- **DynamoDB**: Query logs by service and action type using the GSI

## Cost Considerations

- DynamoDB: Pay-per-request billing mode
- SQS: First 1M requests/month free, then $0.40 per million
- Lambda: First 1M requests/month free
- CloudWatch Logs: 14-day retention

## Security

- Lambda runs in VPC with private subnets
- IAM policies follow principle of least privilege
- SQS queue has resource-based policy limiting access
- All resources tagged with environment information
