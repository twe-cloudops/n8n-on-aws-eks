# Owner Credentials Security

## Problem
Previously, the n8n owner password was hardcoded in the repository (`manifests/01-n8n-owner-secret.yaml`), which is a security risk.

## Solution
Auto-generate a random password during deployment and store it securely in AWS.

## Implementation

### Option 1: SSM Parameter Store (Recommended - Cheaper)
**Cost**: $0.05 per 10,000 API calls

```bash
# Automatically called during deployment
./scripts/create-owner-secret-ssm.sh

# Retrieve password
aws ssm get-parameter \
  --name /n8n/n8n-cluster/owner-password \
  --with-decryption \
  --region ap-southeast-2 \
  --query 'Parameter.Value' \
  --output text
```

### Option 2: Secrets Manager (Alternative)
**Cost**: $0.40 per secret per month

```bash
# Use this if you prefer Secrets Manager
./scripts/create-owner-secret.sh

# Retrieve password
aws secretsmanager get-secret-value \
  --secret-id n8n-owner-credentials-n8n-cluster \
  --region ap-southeast-2 \
  --query 'SecretString' \
  --output text | jq -r '.password'
```

## Password Generation
- 16 characters
- Alphanumeric (base64 encoded)
- Cryptographically secure (using `openssl rand`)

## Security Benefits
1. ✅ No hardcoded passwords in repository
2. ✅ Random password per deployment
3. ✅ Encrypted at rest (AWS KMS)
4. ✅ Access controlled via IAM
5. ✅ Audit trail in CloudTrail

## Deployment Integration
The password is automatically generated and stored during `deploy-full.sh`:

```bash
# Step 3: Deploy n8n
info "Creating owner credentials with random password..."
./scripts/create-owner-secret-ssm.sh
```

## First Login
After deployment:

1. Get the password:
```bash
aws ssm get-parameter \
  --name /n8n/n8n-cluster/owner-password \
  --with-decryption \
  --region ap-southeast-2 \
  --query 'Parameter.Value' \
  --output text
```

2. Login to n8n:
   - Email: `dl.it.cloudops@tweglobal.com`
   - Password: (from step 1)

3. **Change password immediately** through n8n UI

## Cost Comparison

| Service | Cost | Best For |
|---------|------|----------|
| SSM Parameter Store | $0.05 per 10,000 calls | Simple secrets, cost-sensitive |
| Secrets Manager | $0.40/month per secret | Automatic rotation, compliance |

**Recommendation**: Use SSM Parameter Store for this use case (saves ~$5/year per environment).

## Rotation
To rotate the password:

```bash
# Generate new password and update
./scripts/create-owner-secret-ssm.sh

# Or manually
NEW_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
aws ssm put-parameter \
  --name /n8n/n8n-cluster/owner-password \
  --value "$NEW_PASSWORD" \
  --type SecureString \
  --overwrite

# Update Kubernetes secret
kubectl create secret generic n8n-owner-credentials \
  --from-literal=password="$NEW_PASSWORD" \
  --namespace n8n \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart n8n pod
kubectl rollout restart deployment/n8n -n n8n
```

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:GetParameter",
        "ssm:AddTagsToResource"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/n8n/*"
    }
  ]
}
```
