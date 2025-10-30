import json
import boto3
import os
from botocore.exceptions import ClientError

# Initialize AWS clients
textract = boto3.client('textract')
sqs = boto3.client('sqs')

# Environment variables
VERIFICATION_RESULTS_QUEUE_URL = os.environ['VERIFICATION_RESULTS_QUEUE_URL']

def lambda_handler(event, context):
    """
    Triggered by SNS when Textract completes document analysis.
    Retrieves results, parses extracted data, and sends to SQS for ECS processing.
    """
    print(f"Received event: {json.dumps(event)}")
    
    for record in event['Records']:
        try:
            # Parse SNS message
            sns_message = json.loads(record['Sns']['Message'])
            
            job_id = sns_message.get('JobId')
            status = sns_message.get('Status')
            job_tag = sns_message.get('JobTag')
            
            print(f"Processing Textract job: {job_id}, Status: {status}")
            
            if status != 'SUCCEEDED':
                print(f"Textract job {job_id} did not succeed. Status: {status}")
                continue
            
            # Parse job tag to get client info
            job_metadata = json.loads(job_tag) if job_tag else {}
            client_id = job_metadata.get('clientId')
            
            if not client_id:
                print(f"No client ID found in job tag: {job_tag}")
                continue
            
            # Get Textract results
            extracted_data = get_textract_results(job_id, sns_message)
            
            if not extracted_data:
                print(f"No data extracted from Textract job {job_id}")
                continue
            
            # Send results to verification results queue
            send_to_verification_queue(client_id, extracted_data, job_metadata)
            
            print(f"Successfully processed Textract results for client {client_id}")
            
        except Exception as e:
            print(f"Error processing SNS record: {str(e)}")
            raise
    
    return {
        'statusCode': 200,
        'body': json.dumps('Successfully processed Textract results')
    }

def get_textract_results(job_id, sns_message):
    """
    Retrieve and parse Textract analysis results.
    """
    try:
        # Check if results are embedded in SNS message (for sync processing)
        if 'Blocks' in sns_message:
            print("Using embedded blocks from SNS message")
            blocks = sns_message['Blocks']
            return parse_textract_blocks(blocks)
        
        # Otherwise, retrieve from Textract API
        print(f"Retrieving results for job {job_id}")
        
        all_blocks = []
        next_token = None
        
        # Handle pagination
        while True:
            if next_token:
                response = textract.get_document_analysis(
                    JobId=job_id,
                    NextToken=next_token
                )
            else:
                response = textract.get_document_analysis(JobId=job_id)
            
            all_blocks.extend(response.get('Blocks', []))
            
            next_token = response.get('NextToken')
            if not next_token:
                break
        
        return parse_textract_blocks(all_blocks)
        
    except ClientError as e:
        print(f"Error retrieving Textract results: {str(e)}")
        return None

def parse_textract_blocks(blocks):
    """
    Parse Textract blocks and extract meaningful data.
    Extracts text, key-value pairs, and tables.
    """
    extracted_data = {
        'text': [],
        'keyValuePairs': {},
        'tables': []
    }
    
    # Extract LINE blocks for full text
    for block in blocks:
        if block['BlockType'] == 'LINE':
            extracted_data['text'].append(block.get('Text', ''))
    
    # Extract KEY_VALUE_SET blocks for forms
    key_map = {}
    value_map = {}
    block_map = {block['Id']: block for block in blocks}
    
    for block in blocks:
        if block['BlockType'] == 'KEY_VALUE_SET':
            if 'KEY' in block.get('EntityTypes', []):
                key_map[block['Id']] = block
            elif 'VALUE' in block.get('EntityTypes', []):
                value_map[block['Id']] = block
    
    # Match keys with values
    for key_id, key_block in key_map.items():
        if 'Relationships' in key_block:
            for relationship in key_block['Relationships']:
                if relationship['Type'] == 'VALUE':
                    for value_id in relationship['Ids']:
                        if value_id in value_map:
                            key_text = get_text_from_block(key_block, block_map)
                            value_text = get_text_from_block(value_map[value_id], block_map)
                            extracted_data['keyValuePairs'][key_text] = value_text
    
    return extracted_data

def get_text_from_block(block, block_map):
    """
    Extract text from a block and its children.
    """
    text = ''
    if 'Relationships' in block:
        for relationship in block['Relationships']:
            if relationship['Type'] == 'CHILD':
                for child_id in relationship['Ids']:
                    child = block_map.get(child_id)
                    if child and child['BlockType'] == 'WORD':
                        text += child.get('Text', '') + ' '
    return text.strip()

def send_to_verification_queue(client_id, extracted_data, metadata):
    """
    Send extracted data to verification results SQS queue.
    """
    try:
        message = {
            'clientId': client_id,
            'extractedData': extracted_data,
            'metadata': metadata,
            'timestamp': str(boto3.Session().resource('s3').meta.client.meta.events._unique_id)
        }
        
        response = sqs.send_message(
            QueueUrl=VERIFICATION_RESULTS_QUEUE_URL,
            MessageBody=json.dumps(message)
        )
        
        print(f"Sent message to verification queue. MessageId: {response['MessageId']}")
        return response['MessageId']
        
    except ClientError as e:
        print(f"Error sending message to SQS: {str(e)}")
        raise
