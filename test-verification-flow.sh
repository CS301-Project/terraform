#!/bin/bash
# Verification Flow Testing & Monitoring Script

echo "🧪 Document Verification Flow - Test & Monitor"
echo "=============================================="
echo ""

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-southeast-1"

# Queue URLs
REQUEST_QUEUE_URL="https://sqs.$REGION.amazonaws.com/$ACCOUNT_ID/verification-request-queue"
RESULTS_QUEUE_URL="https://sqs.$REGION.amazonaws.com/$ACCOUNT_ID/verification-results-queue"

echo "📧 Test Email: fraser.chua.2022@scis.smu.edu.sg"
echo "🌍 Region: $REGION"
echo "🆔 Account: $ACCOUNT_ID"
echo ""
echo "📋 Verification Flow:"
echo "  1️⃣  Send message to verification-request-queue"
echo "  2️⃣  Email Sender Lambda sends verification email"
echo "  3️⃣  You receive email with presigned S3 URL"
echo "  4️⃣  Upload NRIC document via the link"
echo "  5️⃣  Document Ingest Lambda starts Textract analysis"
echo "  6️⃣  Textract processes document (10-30 seconds)"
echo "  7️⃣  SNS notifies Textract Result Lambda"
echo "  8️⃣  Results sent to verification-results-queue"
echo "  ⏸️  [Flow stops - No polling system yet]"
echo ""

# Function to check queue depth
check_queue() {
    local queue_url=$1
    local queue_name=$2
    
    count=$(aws sqs get-queue-attributes \
        --queue-url "$queue_url" \
        --attribute-names ApproximateNumberOfMessages \
        --query 'Attributes.ApproximateNumberOfMessages' \
        --output text)
    
    echo "📊 $queue_name: $count messages"
}

# Function to tail logs
tail_logs() {
    local log_group=$1
    echo "📜 Tailing logs for $log_group..."
    echo "   (Press Ctrl+C to stop)"
    aws logs tail "$log_group" --follow --format short
}

echo "Choose an action:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 STEP 1: Start Verification Flow"
echo "  1) Send test verification request (clientId + email)"
echo ""
echo "📧 STEP 2: Monitor Email Sending"
echo "  2) Monitor Email Sender Lambda logs"
echo "  3) Check verification-request-queue status"
echo ""
echo "📄 STEP 3-4: Upload Document (Manual via email link)"
echo ""
echo "🤖 STEP 5-6: Monitor Textract Processing"
echo "  4) Monitor Document Ingest Lambda logs"
echo "  5) List recent Textract jobs"
echo "  6) Check Textract job status (requires JobId)"
echo ""
echo "📦 STEP 7-8: Monitor Results"
echo "  7) Monitor Textract Result Lambda logs"
echo "  8) Check verification-results-queue status"
echo "  9) View extracted data from results queue"
echo ""
echo "🔄 Continuous Monitoring"
echo "  10) Monitor all queues (refresh every 5s)"
echo "  11) Full flow monitoring (all logs in parallel)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Enter choice [1-11]: " choice

case $choice in
    1)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📤 STEP 1: Sending Verification Request"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        CLIENT_ID="879130f9-6ade-4c4b-a13e-a59e22f59f8a"
        
        aws sqs send-message \
            --queue-url "$REQUEST_QUEUE_URL" \
            --message-body "{\"clientId\":\"$CLIENT_ID\",\"clientEmail\":\"adriankohcl01@gmail.com\",\"agent_Id\":\"fraserthefairy\",\"agentEmail\":\"adrian.koh.2022@scis.smu.edu.sg\"}"
        
        if [ $? -eq 0 ]; then
            echo "✅ Message sent successfully!"
            echo ""
            echo "📋 Request Details:"
            echo "   Client ID: $CLIENT_ID"
            echo "   Client Email: adriankohcl01@gmail.com"
            echo "   Agent ID: fraserchua"
            echo ""
            echo "� NEXT STEPS:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  2️⃣  Run option 2 to monitor Email Sender Lambda"
            echo "  3️⃣  Check your email (adriankohcl01@gmail.com)"
            echo "  4️⃣  Click verification link in email"
            echo "  5️⃣  Upload your NRIC document (PDF/Image)"
            echo "  6️⃣  Run option 4 to monitor Document Ingest"
            echo "  7️⃣  Run option 7 to monitor Textract Result"
            echo "  8️⃣  Run option 9 to view extracted data"
        else
            echo "❌ Failed to send message"
        fi
        ;;
        
    2)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📧 STEP 2: Monitoring Email Sender Lambda"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Looking for:"
        echo "  ✓ Email sent successfully"
        echo "  ✓ Presigned URL generated"
        echo "  ✓ Log sent to logging queue"
        echo ""
        tail_logs "/aws/lambda/email-sender-lambda"
        ;;
        
    3)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 Verification Request Queue Status"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        check_queue "$REQUEST_QUEUE_URL" "verification-request-queue"
        ;;
        
    4)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📄 STEP 5: Monitoring Document Ingest Lambda"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Looking for:"
        echo "  ✓ Processing document from S3"
        echo "  ✓ Started Textract job {JobId}"
        echo ""
        echo "💡 Copy the JobId to check status (option 6)"
        echo ""
        tail_logs "/aws/lambda/document-ingest-lambda"
        ;;
        
    5)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 Recent Textract Jobs"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        aws textract start-document-analysis \
            --max-results 10 \
            --query 'DocumentAnalysisJobs[*].[JobId,Status,StatusMessage,JobTag]' \
            --output table
        ;;
        
    6)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🔍 Check Textract Job Status"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        read -p "Enter Textract JobId: " job_id
        aws textract get-document-analysis \
            --job-id "$job_id" \
            --query '{JobId:JobId,Status:JobStatus,StatusMessage:StatusMessage,Pages:DocumentMetadata.Pages}' \
            --output table
        ;;
        
    7)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📦 STEP 7: Monitoring Textract Result Lambda"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Looking for:"
        echo "  ✓ Received SNS notification"
        echo "  ✓ Processing Textract job (SUCCEEDED)"
        echo "  ✓ Extracted data structure"
        echo "  ✓ Sent message to verification-results-queue"
        echo ""
        tail_logs "/aws/lambda/textract-result-lambda"
        ;;
        
    8)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 Verification Results Queue Status"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        check_queue "$RESULTS_QUEUE_URL" "verification-results-queue"
        echo ""
        echo "💡 Run option 9 to view the extracted NRIC data"
        ;;
        
    9)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📦 STEP 8: View Extracted Data from Queue"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Retrieving extracted NRIC data..."
        echo ""
        message=$(aws sqs receive-message \
            --queue-url "$RESULTS_QUEUE_URL" \
            --max-number-of-messages 1 \
            --wait-time-seconds 10 \
            --query 'Messages[0].Body' \
            --output text)
        
        if [ -n "$message" ] && [ "$message" != "None" ]; then
            echo "✅ Extracted Data:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$message" | jq '.'
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📋 Data Structure:"
            echo "  • clientId: The test client ID"
            echo "  • extractedData.text: All text lines from NRIC"
            echo "  • extractedData.keyValuePairs: Structured fields (Name, NRIC No., etc.)"
            echo "  • metadata: S3 bucket and file info"
            echo ""
            echo "⏸️  FLOW STOPS HERE"
            echo "   (No Client ECS polling system implemented yet)"
            echo ""
            echo "💡 Next: Implement polling in Client ECS to:"
            echo "   1. Read this queue"
            echo "   2. Compare with RDS data"
            echo "   3. Update verification status"
        else
            echo "ℹ️  No messages in queue"
            echo ""
            echo "Possible reasons:"
            echo "  • Textract still processing (wait 10-30 seconds)"
            echo "  • Document not uploaded yet"
            echo "  • Message already consumed"
            echo ""
            echo "Try running option 7 to check Textract Result Lambda logs"
        fi
        ;;
        
    10)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "� Monitoring All Queues (Continuous)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Refreshing every 5 seconds (Ctrl+C to stop)..."
        echo ""
        while true; do
            clear
            echo "🔄 Queue Status - $(date)"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            check_queue "$REQUEST_QUEUE_URL" "verification-request-queue"
            check_queue "$RESULTS_QUEUE_URL" "verification-results-queue"
            echo ""
            echo "Press Ctrl+C to stop"
            sleep 5
        done
        ;;
        
    11)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎬 Full Flow Monitoring (Parallel Logs)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # This requires tmux or you can run manually
        if command -v tmux &> /dev/null; then
            tmux new-session -d -s verification 'aws logs tail /aws/lambda/email-sender-lambda --follow'
            tmux split-window -v 'aws logs tail /aws/lambda/document-ingest-lambda --follow'
            tmux split-window -v 'aws logs tail /aws/lambda/textract-result-lambda --follow'
            tmux select-layout even-vertical
            tmux attach-session -t verification
        else
            echo "⚠️  tmux not installed. Run these commands in separate terminals:"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Terminal 1 - Email Sender:"
            echo "aws logs tail /aws/lambda/email-sender-lambda --follow"
            echo ""
            echo "Terminal 2 - Document Ingest:"
            echo "aws logs tail /aws/lambda/document-ingest-lambda --follow"
            echo ""
            echo "Terminal 3 - Textract Result:"
            echo "aws logs tail /aws/lambda/textract-result-lambda --follow"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
        ;;
        
    *)
        echo "❌ Invalid choice"
        ;;
esac
