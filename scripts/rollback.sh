#!/bin/bash
set -e

APP_NAME="fukuoka26-static-site"
REGION="us-east-1"

echo "Rolling back to previous deployment..."

APP_ID=$(aws amplify list-apps --region "$REGION" --query "apps[?name=='$APP_NAME'].appId" --output text 2>/dev/null || echo "")

if [ -z "$APP_ID" ]; then
  echo "Error: Amplify app not found"
  exit 1
fi

echo "Found Amplify App ID: $APP_ID"

# Get the second most recent deployment (first is current)
echo "Fetching deployment history..."
PREV_JOB=$(aws amplify list-jobs --app-id "$APP_ID" --branch-name main --region "$REGION" --max-results 2 --query 'jobSummaries[1]' --output json 2>/dev/null || echo "null")

if [ "$PREV_JOB" = "null" ] || [ -z "$PREV_JOB" ]; then
  echo "Error: No previous deployment found"
  echo "This may be the first deployment, or job history is not available"
  exit 1
fi

PREV_COMMIT=$(echo "$PREV_JOB" | grep -o '"commitId": "[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$PREV_COMMIT" ]; then
  echo "Error: Could not extract commit ID from previous deployment"
  exit 1
fi

echo "Rolling back to commit: $PREV_COMMIT"

aws amplify start-job \
  --app-id "$APP_ID" \
  --branch-name main \
  --job-type RELEASE \
  --commit-id "$PREV_COMMIT" \
  --region "$REGION"

echo ""
echo "=========================================="
echo "Rollback initiated successfully!"
echo "=========================================="
echo ""
echo "Check Amplify Console for progress:"
echo "https://console.aws.amazon.com/amplify/home?region=$REGION#/$APP_ID"
echo ""
