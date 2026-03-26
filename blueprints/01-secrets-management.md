# Blueprint: AWS Secrets Manager Integration

**Priority**: CRITICAL
**Effort**: 1-2 days
**Impact**: Eliminates hardcoded credentials vulnerability

---

## Problem

Database credentials are hardcoded in `manifests/01-postgres-secret.yaml` and committed to version control.

---

## Solution

Use AWS Secrets Manager with External Secrets Operator to dynamically inject secrets into Kubernetes.

---

## Implementation

### Step 1: Install External Secrets Operator

```bash
# Install ESO
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/external-secrets.yaml

# Verify installation
kubectl get pods -n external-secrets-system
```

### Step 2: Create AWS Secrets Manager Secret

```bash
# Generate secure password
DB_PASSWORD=$(openssl rand -base64 32)

# Create secret in AWS Secrets Manager
aws secretsmanager create-secret \
  --name n8n/postgres-credentials \
  --description "n8n PostgreSQL credentials" \
  --secret-string "{
    \"username\":\"n8nuser\",
    \"password\":\"${DB_PASSWORD}\",
    \"database\":\"n8n\"
  }" \
  --region ${REGION}
```

### Step 3: Create IAM Role for ESO

**File**: `manifests/secrets/eso-iam-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:n8n/*"
    }
  ]
}
```

```bash
# Create IAM policy
aws iam create-policy \
  --policy-name n8n-secrets-reader \
  --policy-document file://manifests/secrets/eso-iam-policy.json

# Create service account with IAM role
eksctl create iamserviceaccount \
  --name external-secrets \
  --namespace external-secrets-system \
  --cluster ${CLUSTER_NAME} \
  --region ${REGION} \
  --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/n8n-secrets-reader \
  --approve
```

### Step 4: Create SecretStore

**File**: `manifests/secrets/secret-store.yaml`

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: n8n
spec:
  provider:
    aws:
      service: SecretsManager
      region: ${REGION}
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets-system
```

### Step 5: Create ExternalSecret

**File**: `manifests/secrets/postgres-external-secret.yaml`

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgres-credentials
  namespace: n8n
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: postgres-secret
    creationPolicy: Owner
  data:
  - secretKey: POSTGRES_USER
    remoteRef:
      key: n8n/postgres-credentials
      property: username
  - secretKey: POSTGRES_PASSWORD
    remoteRef:
      key: n8n/postgres-credentials
      property: password
  - secretKey: POSTGRES_DB
    remoteRef:
      key: n8n/postgres-credentials
      property: database
  - secretKey: POSTGRES_NON_ROOT_USER
    remoteRef:
      key: n8n/postgres-credentials
      property: username
  - secretKey: POSTGRES_NON_ROOT_PASSWORD
    remoteRef:
      key: n8n/postgres-credentials
      property: password
```

### Step 6: Update Deployment Script

**File**: `scripts/deploy.sh` (add after namespace creation)

```bash
# Install External Secrets Operator
log_info "Installing External Secrets Operator..."
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/external-secrets.yaml

# Wait for ESO to be ready
kubectl wait --for=condition=available --timeout=300s deployment/external-secrets -n external-secrets-system

# Create secrets in AWS Secrets Manager
log_info "Creating secrets in AWS Secrets Manager..."
DB_PASSWORD=$(openssl rand -base64 32)
aws secretsmanager create-secret \
  --name n8n/postgres-credentials \
  --secret-string "{\"username\":\"n8nuser\",\"password\":\"${DB_PASSWORD}\",\"database\":\"n8n\"}" \
  --region "$REGION" \
  --profile "$AWS_PROFILE" 2>/dev/null || \
  aws secretsmanager update-secret \
  --secret-id n8n/postgres-credentials \
  --secret-string "{\"username\":\"n8nuser\",\"password\":\"${DB_PASSWORD}\",\"database\":\"n8n\"}" \
  --region "$REGION" \
  --profile "$AWS_PROFILE"

# Create IAM service account for ESO
log_info "Creating IAM service account for External Secrets..."
eksctl create iamserviceaccount \
  --name external-secrets \
  --namespace external-secrets-system \
  --cluster "$CLUSTER_NAME" \
  --region "$REGION" \
  --attach-policy-arn "arn:aws:iam::aws:policy/SecretsManagerReadWrite" \
  --approve \
  --profile "$AWS_PROFILE" || log_warning "Service account may already exist"

# Apply SecretStore and ExternalSecret
kubectl apply -f "${MANIFEST_DIR}/secrets/secret-store.yaml"
kubectl apply -f "${MANIFEST_DIR}/secrets/postgres-external-secret.yaml"

# Wait for secret to be created
log_info "Waiting for secrets to be synced..."
kubectl wait --for=condition=Ready --timeout=60s externalsecret/postgres-credentials -n n8n
```

### Step 7: Remove Old Secret Manifest

```bash
# Delete hardcoded secret file
rm manifests/01-postgres-secret.yaml

# Update deployment order in deploy.sh
# Remove "01-postgres-secret.yaml" from MANIFEST_FILES array
```

---

## Testing

```bash
# Verify ExternalSecret is synced
kubectl get externalsecret -n n8n
kubectl describe externalsecret postgres-credentials -n n8n

# Verify Kubernetes secret was created
kubectl get secret postgres-secret -n n8n

# Verify secret values
kubectl get secret postgres-secret -n n8n -o jsonpath='{.data.POSTGRES_USER}' | base64 -d
```

---

## Rollback Plan

If issues occur:

```bash
# Recreate hardcoded secret temporarily
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: n8n
type: Opaque
stringData:
  POSTGRES_USER: n8nuser
  POSTGRES_PASSWORD: temporary-password
  POSTGRES_DB: n8n
  POSTGRES_NON_ROOT_USER: n8nuser
  POSTGRES_NON_ROOT_PASSWORD: temporary-password
EOF

# Restart deployments
kubectl rollout restart deployment/postgres -n n8n
kubectl rollout restart deployment/n8n -n n8n
```

---

## Security Benefits

✅ No credentials in version control
✅ Automatic secret rotation capability
✅ Centralized secret management
✅ Audit trail in AWS CloudTrail
✅ Fine-grained IAM permissions

---

## Cost Impact

- External Secrets Operator: Free (open source)
- AWS Secrets Manager: $0.40/secret/month + $0.05/10,000 API calls
- **Estimated**: ~$1/month

---

## Next Steps

After implementation:
1. Test secret rotation
2. Document secret management procedures
3. Set up secret rotation schedule
4. Configure CloudWatch alerts for secret access

---

**Status**: Ready to implement
**Dependencies**: AWS CLI, eksctl, kubectl
**Validation**: All tests pass, no hardcoded credentials remain
