#!/bin/bash
set -euo pipefail

# Alternative: Store password in SSM Parameter Store (cheaper than Secrets Manager)
# SSM Parameter Store: $0.05 per 10,000 API calls
# Secrets Manager: $0.40 per secret per month

CLUSTER_NAME="${CLUSTER_NAME:-n8n-cluster}"
REGION="${REGION:-ap-southeast-2}"
AWS_PROFILE="${AWS_PROFILE:-default}"
PARAMETER_NAME="/n8n/${CLUSTER_NAME}/owner-password"

echo "Creating n8n owner password in SSM Parameter Store..."
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Parameter: $PARAMETER_NAME"

# Generate random password (16 chars, alphanumeric + special)
PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)

echo "✅ Generated random password"

# Store in SSM Parameter Store (SecureString)
aws ssm put-parameter \
  --name "$PARAMETER_NAME" \
  --description "n8n owner password for $CLUSTER_NAME" \
  --value "$PASSWORD" \
  --type SecureString \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --tags "Key=Cluster,Value=$CLUSTER_NAME" \
         "Key=ManagedBy,Value=n8n-deployment" \
  --overwrite \
  > /dev/null

echo "✅ Password stored in SSM Parameter Store: $PARAMETER_NAME"

# Create Kubernetes secret
kubectl create secret generic n8n-owner-credentials \
  --from-literal=email="dl.it.cloudops@tweglobal.com" \
  --from-literal=password="$PASSWORD" \
  --from-literal=first_name="TWE" \
  --from-literal=last_name="CloudOps" \
  --namespace n8n \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Kubernetes secret created: n8n-owner-credentials"

cat << EOF

========================================
n8n Owner Credentials Created
========================================

SSM Parameter: $PARAMETER_NAME
Kubernetes Secret: n8n-owner-credentials (namespace: n8n)

Email: dl.it.cloudops@tweglobal.com
Password: [STORED IN SSM PARAMETER STORE]

To retrieve password:
aws ssm get-parameter \\
  --name $PARAMETER_NAME \\
  --with-decryption \\
  --region $REGION \\
  --query 'Parameter.Value' \\
  --output text

Cost: SSM Parameter Store is cheaper than Secrets Manager
- SSM: \$0.05 per 10,000 API calls
- Secrets Manager: \$0.40 per secret per month

========================================
EOF
