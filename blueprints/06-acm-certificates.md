# Blueprint: AWS Certificate Manager (ACM) Integration

**Priority**: MEDIUM
**Effort**: 30 minutes
**Impact**: Managed TLS certificates, no rate limits

---

## ACM vs cert-manager

| Feature | ACM | cert-manager + Let's Encrypt |
|---------|-----|------------------------------|
| Cost | Free | Free |
| Management | AWS managed | Self-managed |
| Rate Limits | None | 50 certs/week |
| Renewal | Automatic | Automatic |
| Validation | DNS or HTTP | HTTP-01 or DNS-01 |
| Setup Time | 5 minutes | 15 minutes |
| Best For | Production | Development/Testing |

**Recommendation**: Use ACM for production deployments.

---

## Implementation

### Step 1: Request Certificate in ACM

```bash
# Request certificate
aws acm request-certificate \
  --domain-name n8n.example.com \
  --validation-method DNS \
  --region us-east-1

# Get certificate ARN
ACM_CERT_ARN=$(aws acm list-certificates \
  --region us-east-1 \
  --query 'CertificateSummaryList[?DomainName==`n8n.example.com`].CertificateArn' \
  --output text)

echo $ACM_CERT_ARN
```

### Step 2: Validate Certificate

```bash
# Get validation records
aws acm describe-certificate \
  --certificate-arn $ACM_CERT_ARN \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'

# Add CNAME record to Route53 or your DNS provider
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://validation-record.json
```

### Step 3: Deploy with ACM

```bash
# Deploy with ACM certificate
export USE_ACM="true"
export ACM_CERT_ARN="arn:aws:acm:us-east-1:123456789012:certificate/abc-123"
export N8N_DOMAIN="n8n.example.com"
export LB_SCHEME="internet-facing"

./scripts/deploy.sh
```

---

## Usage Examples

### Example 1: ACM with ALB

```bash
export USE_ACM="true"
export ACM_CERT_ARN="arn:aws:acm:us-east-1:123456789012:certificate/abc-123"
export N8N_DOMAIN="n8n.example.com"
export LB_TYPE="alb"
./scripts/deploy.sh
```

### Example 2: ACM with Internal ALB

```bash
export USE_ACM="true"
export ACM_CERT_ARN="arn:aws:acm:us-east-1:123456789012:certificate/abc-123"
export N8N_DOMAIN="n8n.internal.example.com"
export LB_SCHEME="internal"
./scripts/deploy.sh
```

### Example 3: Wildcard Certificate

```bash
# Request wildcard cert
aws acm request-certificate \
  --domain-name "*.example.com" \
  --subject-alternative-names "example.com" \
  --validation-method DNS \
  --region us-east-1

# Deploy
export USE_ACM="true"
export ACM_CERT_ARN="arn:aws:acm:us-east-1:123456789012:certificate/wildcard-123"
export N8N_DOMAIN="n8n.example.com"
./scripts/deploy.sh
```

---

## Comparison: ACM vs cert-manager

### Use ACM When:
✅ Deploying to production
✅ Using AWS infrastructure
✅ Want zero maintenance
✅ Need multiple certificates
✅ Want no rate limits

### Use cert-manager When:
✅ Multi-cloud deployment
✅ Need custom CA
✅ Development/testing
✅ Want full control
✅ Non-AWS environment

---

## Cost

- **ACM**: $0 (free for AWS resources)
- **cert-manager**: $0 (free, open source)
- **Let's Encrypt**: $0 (free)

**Winner**: Tie (both free)

---

## Automation Script

```bash
#!/bin/bash
# Request and validate ACM certificate

DOMAIN="n8n.example.com"
REGION="us-east-1"
HOSTED_ZONE_ID="Z1234567890ABC"

# Request certificate
CERT_ARN=$(aws acm request-certificate \
  --domain-name "$DOMAIN" \
  --validation-method DNS \
  --region "$REGION" \
  --query 'CertificateArn' \
  --output text)

echo "Certificate ARN: $CERT_ARN"

# Wait for validation record
sleep 10

# Get validation record
VALIDATION=$(aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region "$REGION" \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord')

RECORD_NAME=$(echo $VALIDATION | jq -r '.Name')
RECORD_VALUE=$(echo $VALIDATION | jq -r '.Value')

# Create Route53 record
aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"$RECORD_NAME\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$RECORD_VALUE\"}]
      }
    }]
  }"

echo "Waiting for validation..."
aws acm wait certificate-validated \
  --certificate-arn "$CERT_ARN" \
  --region "$REGION"

echo "Certificate validated!"
echo "Use: export ACM_CERT_ARN=$CERT_ARN"
```

---

**Status**: Implemented
**Files**: `manifests/tls/ingress-acm.yaml`, updated `scripts/deploy.sh`
