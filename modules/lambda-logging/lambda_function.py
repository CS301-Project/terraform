import json
import boto3
import os
from datetime import datetime
import uuid

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['DYNAMODB_TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Process SQS messages and write logs to DynamoDB
    
    Expected message format:
    {
        "service_name": "client|account|transaction",
        "action_type": "create|update|delete|verify|fetch|insert",
        "user_id": "optional_user_id",
        "resource_id": "optional_resource_id",
        "metadata": {...},
        "message": "Log message"
    }
    """
    
    processed_count = 0
    failed_count = 0
    
    for record in event['Records']:
        try:
            body = json.loads(record['body'])
            
            # Create log entry with all required fields
            log_entry = {
                'log_id': str(uuid.uuid4()),
                'timestamp': int(datetime.utcnow().timestamp()),
                'service_name': body.get('service_name', 'unknown'),
                'action_type': body.get('action_type', 'unknown'),
                'user_id': body.get('user_id', 'N/A'),
                'resource_id': body.get('resource_id', 'N/A'),
                'message': body.get('message', ''),
                'metadata': json.dumps(body.get('metadata', {})),
                'created_at': datetime.utcnow().isoformat()
            }
            
            # Write to DynamoDB
            table.put_item(Item=log_entry)
            processed_count += 1
            
            print(f"Successfully logged: {log_entry['log_id']} - {log_entry['service_name']}.{log_entry['action_type']}")
            
        except Exception as e:
            failed_count += 1
            print(f"Error processing record: {str(e)}")
            print(f"Record body: {record.get('body', 'N/A')}")
            # Re-raise to send message to DLQ after max retries
            raise e
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Logs processed successfully',
            'processed': processed_count,
            'failed': failed_count
        })
    }
