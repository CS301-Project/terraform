import json
import boto3
import os
from boto3.dynamodb.conditions import Key
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['DYNAMODB_TABLE_NAME']
table = dynamodb.Table(table_name)

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    Read audit logs from DynamoDB
    Query parameters:
    - agent_id: Filter logs by agent ID (optional)
    - limit: Number of records to return (default: 100, max: 1000)
    """
    
    try:
        # Parse query parameters
        query_params = event.get('queryStringParameters') or {}
        agent_id = query_params.get('agent_id')
        limit = min(int(query_params.get('limit', 100)), 1000)
        
        if agent_id:
            # Query by agent_id (requires GSI)
            response = table.query(
                IndexName='agent_id-index',
                KeyConditionExpression=Key('agent_id').eq(agent_id),
                Limit=limit,
                ScanIndexForward=False  # Most recent first
            )
        else:
            # Scan all logs
            response = table.scan(Limit=limit)
        
        items = response.get('Items', [])
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'count': len(items),
                'logs': items,
                'lastEvaluatedKey': response.get('LastEvaluatedKey')
            }, cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(f"Error reading logs: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }