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
            
            if not client_id or not client_email or not agent_email:
                print(f"Invalid message format - missing required fields: {message_body}")
                continue
            
            print(f"Processing verification request for client: {client_id}, email: {client_email}, from agent: {agent_email}")
            
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
                upload_url=presigned_url,
                sender_email=agent_email
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
    Generate a presigned POST for uploading to S3 with HTML form.
    Returns an HTML form that can be used directly in the browser.
    """
    if expiration is None:
        expiration = PRESIGNED_URL_EXPIRATION
    
    try:
        # Create success page (once per Lambda execution)
        create_success_page(bucket_name)
        
        # Generate presigned POST
        success_url = f'https://{bucket_name}.s3.amazonaws.com/upload-success.html'
        presigned_post = s3.generate_presigned_post(
            Bucket=bucket_name,
            Key=object_key,
            Fields={
                'Content-Type': 'application/pdf',
                'success_action_redirect': success_url
            },
            Conditions=[
                {'Content-Type': 'application/pdf'},
                {'success_action_redirect': success_url},
                ['content-length-range', 1, 10485760]  # 1 byte to 10MB
            ],
            ExpiresIn=expiration
        )
        
        # Create HTML form
        html_form = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Document Upload</title>
    <style>
        body {{ font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }}
        h1 {{ color: #333; }}
        .upload-box {{ border: 2px dashed #ccc; padding: 30px; text-align: center; }}
        input[type="file"] {{ margin: 20px 0; }}
        button {{ background: #007bff; color: white; padding: 10px 30px; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; }}
        button:hover {{ background: #0056b3; }}
    </style>
</head>
<body>
    <h1>Upload Your Verification Document</h1>
    <form action="{presigned_post['url']}" method="post" enctype="multipart/form-data">
"""
        for key, value in presigned_post['fields'].items():
            html_form += f'        <input type="hidden" name="{key}" value="{value}" />\n'
        
        html_form += """        <div class="upload-box">
            <p>Please select your PDF NRIC Document (max 10MB)</p>
            <input type="file" name="file" accept=".pdf" required />
            <br><br>
            <button type="submit">Upload Document</button>
        </div>
    </form>
</body>
</html>
"""
        
        # Upload HTML form to S3 and return its URL
        form_key = f"upload-forms/{object_key.replace('documents/', '').replace('.pdf', '')}.html"
        s3.put_object(
            Bucket=bucket_name,
            Key=form_key,
            Body=html_form.encode('utf-8'),
            ContentType='text/html'
        )
        
        form_url = f"https://{bucket_name}.s3.amazonaws.com/{form_key}"
        return form_url
        
    except ClientError as e:
        print(f"Error generating presigned URL: {str(e)}")
        return None

def create_success_page(bucket_name):
    """
    Create and upload a success page to S3 (if it doesn't exist).
    This page is shown after successful document upload.
    """
    try:
        # Check if success page already exists
        try:
            s3.head_object(Bucket=bucket_name, Key='upload-success.html')
            print("Success page already exists, skipping creation")
            return
        except ClientError as e:
            if e.response['Error']['Code'] != '404':
                raise
            # File doesn't exist, create it
        
        success_html = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Upload Successful</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 600px;
            margin: 50px auto;
            padding: 20px;
            text-align: center;
        }
        .success-box {
            background-color: #d4edda;
            border: 2px solid #28a745;
            border-radius: 10px;
            padding: 40px;
            margin: 20px 0;
        }
        .success-icon {
            font-size: 64px;
            color: #28a745;
            margin-bottom: 20px;
        }
        h1 {
            color: #155724;
            margin: 20px 0;
        }
        p {
            color: #155724;
            font-size: 18px;
            line-height: 1.6;
        }
        .info-box {
            background-color: #d1ecf1;
            border: 1px solid #bee5eb;
            border-radius: 5px;
            padding: 15px;
            margin-top: 30px;
            color: #0c5460;
        }
    </style>
</head>
<body>
    <div class="success-box">
        <div class="success-icon">✓</div>
        <h1>Document Uploaded Successfully!</h1>
        <p>Thank you for uploading your verification document.</p>
        <p>We have received your document and it is now being processed.</p>
    </div>
    
    <div class="info-box">
        <p><strong>What happens next?</strong></p>
<p>Our safe and secure AI checker will review your document and try to verify your identity! If there are any issues, your agent will contact you accordingly</p>
    </div>
    
    <p style="color: #666; margin-top: 40px; font-size: 14px;">
        You can safely close this window.
    </p>
</body>
</html>
"""
        
        # Upload success page to S3
        s3.put_object(
            Bucket=bucket_name,
            Key='upload-success.html',
            Body=success_html.encode('utf-8'),
            ContentType='text/html',
            CacheControl='max-age=3600'  # Cache for 1 hour
        )
        
        print("Success page created and uploaded to S3")
        
    except ClientError as e:
        print(f"Error creating success page: {str(e)}")
        # Don't raise - this shouldn't break the main flow

def send_verification_email(recipient_email, client_id, upload_url, sender_email):
    """
    Send verification email using SES template.
    """
    expiration_hours = PRESIGNED_URL_EXPIRATION // 3600
    current_year = datetime.now().year
    
    try:
        params = {
            'Source': sender_email,
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