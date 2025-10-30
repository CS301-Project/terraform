import json
import boto3
import os
from urllib.parse import unquote_plus
from botocore.exceptions import ClientError

# Initialize AWS clients
s3 = boto3.client('s3')
textract = boto3.client('textract')
sns = boto3.client('sns')

# Environment variables
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
SNS_ROLE_ARN = os.environ['SNS_ROLE_ARN']

def lambda_handler(event, context):
    """
    Triggered by S3 object creation. Starts Textract document analysis
    and uses SNS for async completion notification.
    """
    print(f"Received event: {json.dumps(event)}")
    
    for record in event['Records']:
        try:
            # Get bucket and object key from S3 event
            bucket_name = record['s3']['bucket']['name']
            object_key = unquote_plus(record['s3']['object']['key'])
            
            print(f"Processing document: s3://{bucket_name}/{object_key}")
            
            # Extract client ID from object key (assumes format: documents/{clientId}/...)
            client_id = extract_client_id(object_key)
            if not client_id:
                print(f"Could not extract client ID from object key: {object_key}")
                continue
            
            # Start Textract document analysis (async)
            response = start_textract_analysis(bucket_name, object_key, client_id)
            
            if response:
                job_id = response['JobId']
                print(f"Started Textract job {job_id} for client {client_id}")
            else:
                print(f"Failed to start Textract analysis for {object_key}")
                
        except Exception as e:
            print(f"Error processing record: {str(e)}")
            raise
    
    return {
        'statusCode': 200,
        'body': json.dumps('Successfully started Textract analysis')
    }

def extract_client_id(object_key):
    """
    Extract client ID from S3 object key.
    Expected format: documents/{clientId}/filename.pdf
    """
    try:
        parts = object_key.split('/')
        if len(parts) >= 2 and parts[0] == 'documents':
            return parts[1]
    except Exception as e:
        print(f"Error extracting client ID: {str(e)}")
    return None

def start_textract_analysis(bucket_name, object_key, client_id):
    """
    Start asynchronous Textract document analysis.
    """
    try:
        response = textract.start_document_analysis(
            DocumentLocation={
                'S3Object': {
                    'Bucket': bucket_name,
                    'Name': object_key
                }
            },
            FeatureTypes=['TABLES', 'FORMS'],  # Extract tables and forms
            NotificationChannel={
                'SNSTopicArn': SNS_TOPIC_ARN,
                'RoleArn': SNS_ROLE_ARN
            },
            ClientRequestToken=f"{client_id}-{object_key.split('/')[-1]}",  # Idempotency
            JobTag=json.dumps({
                'clientId': client_id,
                'bucket': bucket_name,
                'key': object_key
            })
        )
        return response
        
    except ClientError as e:
        print(f"Error starting Textract analysis: {str(e)}")
        # For smaller documents, try synchronous analysis as fallback
        try:
            print("Attempting synchronous analysis as fallback...")
            return analyze_document_sync(bucket_name, object_key, client_id)
        except Exception as sync_error:
            print(f"Synchronous analysis also failed: {str(sync_error)}")
            return None

def analyze_document_sync(bucket_name, object_key, client_id):
    """
    Fallback: Synchronous document analysis for small documents.
    This bypasses the SNS notification and directly processes the result.
    """
    try:
        # Get document from S3
        s3_object = s3.get_object(Bucket=bucket_name, Key=object_key)
        document_bytes = s3_object['Body'].read()
        
        # Analyze document
        response = textract.analyze_document(
            Document={'Bytes': document_bytes},
            FeatureTypes=['TABLES', 'FORMS']
        )
        
        # Manually trigger SNS notification with the results
        # This simulates the async flow for consistency
        sns_message = {
            'JobId': 'sync-' + client_id,
            'Status': 'SUCCEEDED',
            'API': 'AnalyzeDocument',
            'JobTag': json.dumps({
                'clientId': client_id,
                'bucket': bucket_name,
                'key': object_key
            }),
            'DocumentLocation': {
                'S3ObjectName': object_key,
                'S3Bucket': bucket_name
            },
            'Blocks': response.get('Blocks', [])
        }
        
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=json.dumps(sns_message),
            Subject='Textract Analysis Complete (Sync)'
        )
        
        return {'JobId': 'sync-' + client_id}
        
    except Exception as e:
        print(f"Error in synchronous analysis: {str(e)}")
        raise
