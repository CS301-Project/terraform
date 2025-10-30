import json
import boto3
import os
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

# Initialize AWS clients
sqs = boto3.client('sqs')
s3 = boto3.client('s3')
ses = boto3.client('ses')

# Environment variables
BUCKET_NAME = os.environ['BUCKET_NAME']
SENDER_EMAIL = os.environ['SENDER_EMAIL']
TEMPLATE_NAME = os.environ.get('TEMPLATE_NAME', 'verification-email-template')
PRESIGNED_URL_EXPIRATION = int(os.environ.get('PRESIGNED_URL_EXPIRATION', '86400'))  # 24 hours default
CONFIGURATION_SET = os.environ.get('CONFIGURATION_SET', '')
LOGGING_QUEUE_URL = os.environ.get('LOGGING_QUEUE_URL', '')

def lambda_handler(event, context):
    """
    Reads verification requests from SQS queue, generates presigned URLs,
    and sends verification emails via SES.
    """
    print(f"Received event: {json.dumps(event)}")
    
    # Process each SQS message
    for record in event['Records']:
        try:
            # Parse message body
            message_body = json.loads(record['body'])
            client_id = message_body.get('clientId')
            client_email = message_body.get('clientEmail')
            agent_id = message_body.get('agent_Id')
            agent_email = message_body.get('agentEmail')
            
            if not client_id or not client_email:
                print(f"Invalid message format: {message_body}")
                continue
            
            print(f"Processing verification request for client: {client_id}, email: {client_email}")
            
            # Generate presigned URL for document upload
            object_key = f"documents/{client_id}/{datetime.now().strftime('%Y%m%d%H%M%S')}.pdf"
            presigned_url = generate_presigned_url(BUCKET_NAME, object_key)
            
            if not presigned_url:
                print(f"Failed to generate presigned URL for client: {client_id}")
                continue
            
            # Send verification email
            message_id = send_verification_email(
                recipient_email=client_email,
                client_id=client_id,
                upload_url=presigned_url
            )
            
            print(f"Successfully sent verification email to {client_email}")
            
            # Send log to logging SQS queue
            if LOGGING_QUEUE_URL:
                send_log_to_sqs(
                    crud_operation="Create",
                    attribute_name="Verification Email",
                    before_value="",
                    after_value="",
                    agent_id=agent_id,
                    client_id=client_id,
                    remarks=f"Verification email sent. SES MessageId: {message_id}"
                )
            
        except Exception as e:
            print(f"Error processing record: {str(e)}")
            raise  # Let Lambda retry or send to DLQ
    
    return {
        'statusCode': 200,
        'body': json.dumps('Successfully processed verification requests')
    }

def generate_presigned_url(bucket_name, object_key, expiration=None):
    """
    Generate a presigned URL for uploading to S3.
    """
    if expiration is None:
        expiration = PRESIGNED_URL_EXPIRATION
    
    try:
        presigned_url = s3.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': bucket_name,
                'Key': object_key,
                'ContentType': 'application/pdf'  # Adjust as needed
            },
            ExpiresIn=expiration
        )
        return presigned_url
    except ClientError as e:
        print(f"Error generating presigned URL: {str(e)}")
        return None

def send_verification_email(recipient_email, client_id, upload_url):
    """
    Send verification email using SES template.
    """
    expiration_hours = PRESIGNED_URL_EXPIRATION // 3600
    current_year = datetime.now().year
    
    try:
        params = {
            'Source': SENDER_EMAIL,
            'Destination': {
                'ToAddresses': [recipient_email]
            },
            'Template': TEMPLATE_NAME,
            'TemplateData': json.dumps({
                'uploadUrl': upload_url,
                'expirationHours': str(expiration_hours),
                'year': str(current_year),
                'clientId': client_id
            })
        }
        
        # Add configuration set if specified
        if CONFIGURATION_SET:
            params['ConfigurationSetName'] = CONFIGURATION_SET
        
        response = ses.send_templated_email(**params)
        print(f"Email sent successfully. MessageId: {response['MessageId']}")
        return response['MessageId']
        
    except ClientError as e:
        print(f"Error sending email: {str(e)}")
        raise

def send_log_to_sqs(crud_operation, attribute_name, before_value, after_value, agent_id, client_id, remarks=""):
    """
    Send log message to logging SQS queue.
    """
    if not LOGGING_QUEUE_URL:
        return
    
    try:
        log_message = {
            "crud_operation": crud_operation,
            "attribute_name": attribute_name,
            "before_value": before_value,
            "after_value": after_value,
            "agent_id": agent_id,
            "client_id": client_id,
            "datetime": datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
            "remarks": remarks
        }
        
        response = sqs.send_message(
            QueueUrl=LOGGING_QUEUE_URL,
            MessageBody=json.dumps(log_message)
        )
        
        print(f"Log sent to logging queue. MessageId: {response['MessageId']}")
        return response['MessageId']
        
    except ClientError as e:
        print(f"Error sending log to SQS: {str(e)}")
        # Don't raise - logging failure shouldn't break the main flow
