#!/bin/bash
set -e

# Configuration
APP_NAME="fukuoka26-static-site"
S3_BUCKET="fukuoka26-assets"
REGION="us-east-1"

echo "=========================================="
echo "AWS Infrastructure Cleanup Script"
echo "=========================================="
echo ""
echo "WARNING: This will delete all AWS resources for $APP_NAME"
echo "  - Amplify app and all deployments"
echo "  - S3 bucket: $S3_BUCKET (including all images)"
echo "  - CloudWatch alarms"
echo "  - SNS topic for alerts"
echo ""
echo "This action CANNOT be undone!"
echo ""

read -p "Are you absolutely sure? Type 'yes' to proceed: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted - No resources were deleted"
  exit 0
fi

echo ""
echo "Starting cleanup process..."

# 1. Delete Amplify app
echo "Checking for Amplify app..."
APP_ID=$(aws amplify list-apps --region "$REGION" --query "apps[?name=='$APP_NAME'].appId" --output text 2>/dev/null || echo "")
if [ -n "$APP_ID" ]; then
  echo "Deleting Amplify app (ID: $APP_ID)..."
  aws amplify delete-app --app-id "$APP_ID" --region "$REGION" 2>/dev/null || echo "Warning: Amplify app deletion failed"
  echo "✓ Amplify app deleted"
else
  echo "No Amplify app found"
fi

# 2. Empty and delete S3 bucket
echo "Checking for S3 bucket..."
if aws s3 ls "s3://$S3_BUCKET" --region "$REGION" >/dev/null 2>&1; then
  echo "Emptying S3 bucket..."
  aws s3 rm "s3://$S3_BUCKET" --recursive --region "$REGION" 2>/dev/null || echo "Warning: Could not empty bucket"

  echo "Deleting S3 bucket..."
  aws s3api delete-bucket --bucket "$S3_BUCKET" --region "$REGION" 2>/dev/null || echo "Warning: Bucket deletion failed"
  echo "✓ S3 bucket deleted"
else
  echo "No S3 bucket found"
fi

# 3. Delete CloudWatch alarms
echo "Deleting CloudWatch alarms..."
aws cloudwatch delete-alarms \
  --alarm-names "$APP_NAME-build-failure" "fukuoka26-traffic-spike" \
  --region "$REGION" 2>/dev/null || echo "Warning: Alarm deletion failed or alarms not found"
echo "✓ CloudWatch alarms deleted"

# 4. Delete SNS topic
echo "Checking for SNS topic..."
SNS_ARN=$(aws sns list-topics --region "$REGION" --query "Topics[?contains(TopicArn, 'amplify-alerts')].TopicArn" --output text 2>/dev/null || echo "")
if [ -n "$SNS_ARN" ]; then
  echo "Deleting SNS topic..."
  aws sns delete-topic --topic-arn "$SNS_ARN" --region "$REGION" 2>/dev/null || echo "Warning: SNS topic deletion failed"
  echo "✓ SNS topic deleted"
else
  echo "No SNS topic found"
fi

echo ""
echo "=========================================="
echo "Cleanup complete!"
echo "=========================================="
echo ""
echo "Deleted resources:"
echo "  - Amplify app: $APP_NAME"
echo "  - S3 bucket: $S3_BUCKET"
echo "  - CloudWatch alarms: build-failure, traffic-spike"
echo "  - SNS topic: amplify-alerts"
echo ""
echo "NOTE: Route 53 Hosted Zone (if created) must be deleted manually"
echo "      Cost: \$0.50/month will continue until manually deleted"
echo ""
echo "To delete Route 53 Hosted Zone:"
echo "  1. Go to AWS Console > Route 53 > Hosted Zones"
echo "  2. Select fukuoka26.com"
echo "  3. Delete all records except NS and SOA"
echo "  4. Delete the Hosted Zone"
echo ""
