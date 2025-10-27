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
    Process SQS messages and write audit logs to DynamoDB
    
    Expected message format:
    {
        "crud_operation": "Create|Read|Update|Delete",
        "attribute_name": "First Name|Address",
        "before_value": "LEE|ABC",
        "after_value": "TAN|XX",
        "agent_id": "agent_123",
        "client_id": "client_456",
        "datetime": "2025-10-27T10:30:00Z",
        "remarks": "Optional remarks"
    }
    
    Note: 
    - For Create, Read, Delete: store client_id (before_value and after_value may be empty)
    - For Update: store attribute_name, before_value, and after_value
    """
    
    processed_count = 0
    failed_count = 0
    
    for record in event['Records']:
        try:
            body = json.loads(record['body'])
            
            # Validate required fields
            crud_operation = body.get('crud_operation', '').strip()
            if crud_operation not in ['Create', 'Read', 'Update', 'Delete']:
                raise ValueError(f"Invalid CRUD operation: {crud_operation}")
            
            # Use provided datetime or generate current datetime in ISO 8601 format
            log_datetime = body.get('datetime', datetime.utcnow().isoformat() + 'Z')
            
            # Create base log entry
            log_entry = {
                'log_id': str(uuid.uuid4()),
                'datetime': log_datetime,
                'crud_operation': crud_operation,
                'agent_id': body.get('agent_id', 'N/A'),
                'client_id': body.get('client_id', 'N/A'),
            }
            
            # Add operation-specific fields
            # if crud_operation == 'Update':
            #     # For Update: store attribute name and values
            #     log_entry['attribute_name'] = body.get('attribute_name', 'N/A')
            #     log_entry['before_value'] = body.get('before_value', 'N/A')
            #     log_entry['after_value'] = body.get('after_value', 'N/A')
            # else:
            #     # For Create, Read, Delete: client_id is already in base fields
            #     # Store attribute_name, before_value, after_value if provided
            log_entry['attribute_name'] = body.get('attribute_name', 'N/A')
            log_entry['before_value'] = body.get('before_value', 'N/A')
            log_entry['after_value'] = body.get('after_value', 'N/A')
            log_entry['remarks'] = body.get('remarks', 'N/A')
            
            # Write to DynamoDB
            table.put_item(Item=log_entry)
            processed_count += 1
            
            print(f"Successfully logged: {log_entry['log_id']} - {crud_operation} for client {log_entry['client_id']} by agent {log_entry['agent_id']}")
            
        except Exception as e:
            failed_count += 1
            print(f"Error processing record: {str(e)}")
            print(f"Record body: {record.get('body', 'N/A')}")
            # Re-raise to send message to DLQ after max retries
            raise e
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Audit logs processed successfully',
            'processed': processed_count,
            'failed': failed_count
        })
    }
