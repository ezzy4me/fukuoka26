#!/bin/bash
set -e

# Configuration
DOMAIN="fukuoka26.com"
S3_BUCKET="fukuoka26-assets"
APP_NAME="fukuoka26-static-site"
GITHUB_REPO="${GITHUB_REPO:-ezzy4me/fukuoka26}"
GITHUB_TOKEN="${GITHUB_TOKEN}"  # Environment variable
REGION="us-east-1"
IMAGE_DIR="${FRONTAGENT_REF_DIR:-/Users/sangmin/Desktop/Claude/Projects/frontagent/Ref}"

# Validate required environment variables
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN environment variable not set"
  echo "Please set it: export GITHUB_TOKEN=your_token_here"
  exit 1
fi

# Validate GITHUB_REPO is not placeholder
if [[ "$GITHUB_REPO" == *"your-username"* ]]; then
  echo "Error: GITHUB_REPO contains placeholder 'your-username'"
  echo "Please set: export GITHUB_REPO=your-username/fukuoka26"
  echo "Or update line 8 in scripts/deploy.sh with actual GitHub username"
  exit 1
fi

# Validate public/ directory has content
if [ ! -d "public" ] || [ -z "$(ls -A public 2>/dev/null)" ]; then
  echo "Error: public/ directory is empty or missing"
  echo "Run ./scripts/sync-from-frontagent.sh first"
  exit 1
fi

echo "Starting AWS deployment for $DOMAIN..."

# 1. Create S3 bucket for images
echo "Creating S3 bucket: $S3_BUCKET"
aws s3api create-bucket \
  --bucket "$S3_BUCKET" \
  --region "$REGION" \
  || echo "Bucket already exists or error occurred"

# 2. Enable public access for S3 bucket (secure configuration)
echo "Configuring S3 bucket public access..."
aws s3api put-public-access-block \
  --bucket "$S3_BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false" \
  || echo "Public access block already configured"

# Wait a moment for the setting to propagate
sleep 2

# 3. Apply bucket policy
echo "Applying S3 bucket policy..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
aws s3api put-bucket-policy \
  --bucket "$S3_BUCKET" \
  --policy file://"$PROJECT_ROOT/infra/s3-policy.json" \
  || echo "Bucket policy application failed or already exists"

# 3.5. Configure CORS for security
echo "Configuring S3 CORS..."
cat > /tmp/s3-cors-$$.json <<'EOF'
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET"],
    "AllowedOrigins": ["https://fukuoka26.com", "https://www.fukuoka26.com"],
    "ExposeHeaders": [],
    "MaxAgeSeconds": 3000
  }
]
EOF
aws s3api put-bucket-cors \
  --bucket "$S3_BUCKET" \
  --cors-configuration file:///tmp/s3-cors-$$.json \
  || echo "CORS configuration failed"
rm -f /tmp/s3-cors-$$.json
echo "✓ CORS configuration applied"

# 4. Enable S3 versioning for backup
echo "Enabling S3 versioning..."
aws s3api put-bucket-versioning \
  --bucket "$S3_BUCKET" \
  --versioning-configuration Status=Enabled \
  || echo "Versioning already enabled or failed"

# 5. Upload images to S3
if [ -d "$IMAGE_DIR" ]; then
  # Validate image size to avoid exceeding Free Tier
  TOTAL_SIZE_KB=$(du -sk "$IMAGE_DIR" 2>/dev/null | awk '{print $1}' || echo "0")
  TOTAL_SIZE_GB=$(echo "scale=2; $TOTAL_SIZE_KB / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
  echo "Total image size: ${TOTAL_SIZE_GB}GB (Free tier: 5GB)"

  if command -v bc >/dev/null 2>&1; then
    if (( $(echo "$TOTAL_SIZE_GB > 5" | bc -l 2>/dev/null || echo 0) )); then
      OVERAGE_COST=$(echo "scale=2; ($TOTAL_SIZE_GB - 5) * 0.023" | bc -l)
      echo "⚠️  WARNING: Images exceed 5GB free tier. Estimated additional cost: \$${OVERAGE_COST}/month"
    fi
  fi

  echo "Uploading images to S3..."
  aws s3 sync "$IMAGE_DIR" "s3://$S3_BUCKET/images/" \
    --exclude "*" \
    --include "*.png" \
    --include "*.jpg" \
    --include "*.jpeg" \
    --include "*.gif" \
    --include "*.svg" \
    --include "*.webp"
  echo "Image upload completed!"
else
  echo "Warning: Image directory not found at $IMAGE_DIR"
fi

# 6. Create Amplify app
echo "Creating Amplify app: $APP_NAME"
APP_ID=$(aws amplify list-apps --region "$REGION" --query "apps[?name=='$APP_NAME'].appId" --output text)

if [ -z "$APP_ID" ]; then
  echo "Creating new Amplify app..."
  APP_ID=$(aws amplify create-app \
    --name "$APP_NAME" \
    --repository "$GITHUB_REPO" \
    --access-token "$GITHUB_TOKEN" \
    --region "$REGION" \
    --query 'app.appId' \
    --output text)
  echo "Amplify App created with ID: $APP_ID"
else
  echo "Amplify App already exists with ID: $APP_ID"
fi

# 7. Create main branch
echo "Creating main branch in Amplify..."
aws amplify create-branch \
  --app-id "$APP_ID" \
  --branch-name main \
  --region "$REGION" \
  || echo "Branch already exists"

# 8. Connect custom domain
echo "Connecting custom domain: $DOMAIN"
aws amplify create-domain-association \
  --app-id "$APP_ID" \
  --domain-name "$DOMAIN" \
  --sub-domain-settings prefix=,branchName=main \
  --region "$REGION" \
  || echo "Domain already connected or manual configuration needed"

echo "Waiting for domain verification..."
sleep 5

# 8. Start deployment
echo "Starting deployment..."
aws amplify start-job \
  --app-id "$APP_ID" \
  --branch-name main \
  --job-type RELEASE \
  --region "$REGION" \
  || echo "Deployment start failed or already in progress"

# 9. Setup CloudWatch alarm for build failures
echo "Setting up CloudWatch alarm..."
SNS_TOPIC_ARN=$(aws sns list-topics --region "$REGION" --query "Topics[?contains(TopicArn, 'amplify-alerts')].TopicArn" --output text 2>/dev/null || echo "")
if [ -z "$SNS_TOPIC_ARN" ]; then
  echo "Creating SNS topic for alerts..."
  SNS_TOPIC_ARN=$(aws sns create-topic --name amplify-alerts --region "$REGION" --query 'TopicArn' --output text 2>/dev/null || echo "")
  if [ -n "$SNS_TOPIC_ARN" ]; then
    echo "SNS Topic created: $SNS_TOPIC_ARN"
    echo "Note: Subscribe your email to this topic in AWS Console to receive alerts"
  else
    echo "Warning: SNS topic creation failed. Skipping alarm setup."
  fi
fi

if [ -n "$SNS_TOPIC_ARN" ]; then
  # Alarm 1: Build failure detection
  aws cloudwatch put-metric-alarm \
    --alarm-name "$APP_NAME-build-failure" \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 1 \
    --metric-name BuildErrors \
    --namespace AWS/Amplify \
    --period 300 \
    --statistic Sum \
    --threshold 1 \
    --alarm-actions "$SNS_TOPIC_ARN" \
    --dimensions Name=App,Value="$APP_ID" \
    --region "$REGION" \
    || echo "Warning: Build failure alarm creation failed or already exists"

  # Alarm 2: Abnormal traffic detection
  echo "Setting up traffic spike alarm..."
  aws cloudwatch put-metric-alarm \
    --alarm-name "fukuoka26-traffic-spike" \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --metric-name Requests \
    --namespace AWS/CloudFront \
    --period 300 \
    --statistic Sum \
    --threshold 10000 \
    --alarm-actions "$SNS_TOPIC_ARN" \
    --region "$REGION" \
    || echo "Warning: Traffic spike alarm creation failed or already exists"

  echo "✓ CloudWatch alarms configured"
fi

echo ""
echo "=========================================="
echo "Deployment initiated successfully!"
echo "=========================================="
echo ""
echo "Amplify App ID: $APP_ID"
echo "S3 Bucket: $S3_BUCKET"
echo "Domain: $DOMAIN"
echo ""
echo "Next steps:"
echo "1. Visit AWS Amplify Console to monitor build progress:"
echo "   https://console.aws.amazon.com/amplify/home?region=$REGION#/$APP_ID"
echo ""
echo "2. Domain connection:"
echo "   - Automatic domain association initiated"
echo "   - Verify in Amplify Console > Domain management"
echo "   - DNS propagation may take up to 48 hours"
echo ""
echo "3. Route 53 Hosted Zone setup (manual step):"
echo "   - Create Hosted Zone for fukuoka26.com in Route 53"
echo "   - Update NS records at your domain registrar"
echo "   - Create A record (Alias) pointing to Amplify app"
echo ""
echo "4. Test deployment after build completes:"
echo "   ./scripts/test-deployment.sh"
echo ""
echo "5. Optional: Subscribe to SNS alerts"
if [ -n "$SNS_TOPIC_ARN" ]; then
  echo "   aws sns subscribe --topic-arn $SNS_TOPIC_ARN --protocol email --notification-endpoint your-email@example.com"
fi
echo ""
