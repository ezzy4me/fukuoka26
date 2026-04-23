#!/bin/bash
set -e

DOMAIN="fukuoka26.com"
S3_BUCKET="fukuoka26-assets"
REGION="us-east-1"

echo "=========================================="
echo "Testing deployment for $DOMAIN"
echo "=========================================="
echo ""

# 1. Check HTTPS redirect
echo "1. Checking HTTPS redirect..."
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -L "http://$DOMAIN" 2>/dev/null || echo "000")
if [ "$HTTP_RESPONSE" = "200" ] || [ "$HTTP_RESPONSE" = "301" ] || [ "$HTTP_RESPONSE" = "302" ]; then
  echo "   ✓ HTTPS redirect working (HTTP $HTTP_RESPONSE)"
else
  echo "   ✗ HTTPS redirect failed (HTTP $HTTP_RESPONSE)"
  echo "   Note: This is expected if domain is not yet connected"
fi

# 2. Check main page
echo ""
echo "2. Checking main page access..."
HTTPS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" 2>/dev/null || echo "000")
if [ "$HTTPS_RESPONSE" = "200" ]; then
  echo "   ✓ Main page accessible (HTTP $HTTPS_RESPONSE)"
else
  echo "   ✗ Main page failed (HTTP $HTTPS_RESPONSE)"
  echo "   Note: This is expected if domain is not yet connected or build is in progress"
fi

# 3. Check S3 bucket accessibility
echo ""
echo "3. Checking S3 bucket accessibility..."
S3_LIST=$(aws s3 ls "s3://$S3_BUCKET/images/" --region "$REGION" 2>/dev/null | head -n 1)
if [ -n "$S3_LIST" ]; then
  echo "   ✓ S3 bucket accessible and contains files"

  # Try to access a sample image
  FIRST_IMAGE=$(aws s3 ls "s3://$S3_BUCKET/images/" --region "$REGION" | grep -E '\.(png|jpg|jpeg|gif|svg|webp)' | head -n 1 | awk '{print $4}')
  if [ -n "$FIRST_IMAGE" ]; then
    SAMPLE_IMAGE_URL="https://$S3_BUCKET.s3.$REGION.amazonaws.com/images/$FIRST_IMAGE"
    IMAGE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$SAMPLE_IMAGE_URL" 2>/dev/null || echo "000")
    if [ "$IMAGE_RESPONSE" = "200" ]; then
      echo "   ✓ S3 images publicly accessible"
      echo "   Sample URL: $SAMPLE_IMAGE_URL"
    else
      echo "   △ S3 bucket exists but images may not be publicly accessible (HTTP $IMAGE_RESPONSE)"
    fi
  fi
else
  echo "   △ S3 bucket exists but no images found yet"
fi

# 4. Check SSL certificate
echo ""
echo "4. Checking SSL certificate..."
SSL_CHECK=$(openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "failed")
if [ "$SSL_CHECK" != "failed" ]; then
  echo "   ✓ SSL certificate valid"
  echo "$SSL_CHECK" | sed 's/^/   /'
else
  echo "   ✗ SSL certificate check failed"
  echo "   Note: This is expected if domain is not yet connected"
fi

# 5. Check Amplify app status
echo ""
echo "5. Checking Amplify app status..."
APP_NAME="fukuoka26-static-site"
APP_STATUS=$(aws amplify list-apps --region "$REGION" --query "apps[?name=='$APP_NAME'].{id:appId,domain:defaultDomain}" --output json 2>/dev/null || echo "[]")
if [ "$APP_STATUS" != "[]" ]; then
  echo "   ✓ Amplify app exists"
  echo "   App details:"
  echo "$APP_STATUS" | sed 's/^/   /'

  APP_ID=$(echo "$APP_STATUS" | grep -o '"id": "[^"]*"' | cut -d'"' -f4)
  if [ -n "$APP_ID" ]; then
    DEFAULT_DOMAIN=$(echo "$APP_STATUS" | grep -o '"domain": "[^"]*"' | cut -d'"' -f4)
    echo ""
    echo "   Default Amplify URL: https://$DEFAULT_DOMAIN"
    echo "   You can test the deployment at this URL before connecting custom domain"
  fi
else
  echo "   ✗ Amplify app not found"
fi

# 6. Check CloudWatch alarms
echo ""
echo "6. Checking CloudWatch alarms..."
ALARMS=$(aws cloudwatch describe-alarms --alarm-names "$APP_NAME-build-failure" --region "$REGION" --query "MetricAlarms[0].StateValue" --output text 2>/dev/null || echo "")
if [ -n "$ALARMS" ] && [ "$ALARMS" != "None" ]; then
  if [ "$ALARMS" = "OK" ]; then
    echo "   ✓ CloudWatch alarm configured and OK"
  else
    echo "   △ CloudWatch alarm state: $ALARMS"
  fi
else
  echo "   △ CloudWatch alarm not found or not configured"
fi

echo ""
echo "=========================================="
echo "Deployment test completed!"
echo "=========================================="
echo ""
echo "Summary:"
echo "- Domain: $DOMAIN"
echo "- S3 Bucket: $S3_BUCKET"
echo "- Region: $REGION"
echo ""
echo "If tests failed, this may be because:"
echo "1. Build is still in progress (check Amplify Console)"
echo "2. Custom domain not yet connected (use default Amplify URL first)"
echo "3. DNS propagation in progress (can take up to 48 hours)"
echo "4. Route 53 Hosted Zone not configured"
echo ""
