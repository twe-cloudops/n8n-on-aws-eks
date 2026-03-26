#!/bin/bash
set -euo pipefail

# Generate random password and store in AWS Secrets Manager
# Then create Kubernetes secret from Secrets Manager

CLUSTER_NAME="${CLUSTER_NAME:-n8n-cluster}"
REGION="${REGION:-ap-southeast-2}"
AWS_PROFILE="${AWS_PROFILE:-default}"
SECRET_NAME="n8n-owner-credentials-${CLUSTER_NAME}"

echo "Creating n8n owner credentials in AWS Secrets Manager..."
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Secret: $SECRET_NAME"

# Generate random password (16 chars, alphanumeric + special)
PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)

echo "✅ Generated random password"

# Create secret in Secrets Manager
aws secretsmanager create-secret \
  --name "$SECRET_NAME" \
  --description "n8n owner credentials for $CLUSTER_NAME" \
  --secret-string "{
    \"email\": \"dl.it.cloudops@tweglobal.com\",
    \"password\": \"$PASSWORD\",
    \"first_name\": \"TWE\",
    \"last_name\": \"CloudOps\"
  }" \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --tags "Key=Cluster,Value=$CLUSTER_NAME" \
         "Key=ManagedBy,Value=n8n-deployment" \
  > /dev/null 2>&1 || {
    echo "Secret already exists, updating..."
    aws secretsmanager update-secret \
      --secret-id "$SECRET_NAME" \
      --secret-string "{
        \"email\": \"dl.it.cloudops@tweglobal.com\",
        \"password\": \"$PASSWORD\",
        \"first_name\": \"TWE\",
        \"last_name\": \"CloudOps\"
      }" \
      --region "$REGION" \
      --profile "$AWS_PROFILE" \
      > /dev/null
  }

echo "✅ Secret stored in AWS Secrets Manager: $SECRET_NAME"

# Retrieve secret and create Kubernetes secret
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --query 'SecretString' \
  --output text)

EMAIL=$(echo "$SECRET_JSON" | jq -r '.email')
PASSWORD=$(echo "$SECRET_JSON" | jq -r '.password')
FIRST_NAME=$(echo "$SECRET_JSON" | jq -r '.first_name')
LAST_NAME=$(echo "$SECRET_JSON" | jq -r '.last_name')

# Create Kubernetes secret
kubectl create secret generic n8n-owner-credentials \
  --from-literal=email="$EMAIL" \
  --from-literal=password="$PASSWORD" \
  --from-literal=first_name="$FIRST_NAME" \
  --from-literal=last_name="$LAST_NAME" \
  --namespace n8n \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Kubernetes secret created: n8n-owner-credentials"

cat << EOF

========================================
n8n Owner Credentials Created
========================================

AWS Secrets Manager: $SECRET_NAME
Kubernetes Secret: n8n-owner-credentials (namespace: n8n)

Email: $EMAIL
Password: [STORED IN SECRETS MANAGER]

To retrieve password:
aws secretsmanager get-secret-value \\
  --secret-id $SECRET_NAME \\
  --region $REGION \\
  --query 'SecretString' \\
  --output text | jq -r '.password'

Or use SSM Parameter Store (alternative):
aws ssm get-parameter \\
  --name /n8n/$CLUSTER_NAME/owner-password \\
  --with-decryption \\
  --region $REGION \\
  --query 'Parameter.Value' \\
  --output text

========================================
EOF
