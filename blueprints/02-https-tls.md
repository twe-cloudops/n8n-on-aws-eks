# Blueprint: HTTPS/TLS with cert-manager

**Priority**: CRITICAL
**Effort**: 1 day
**Impact**: Encrypts all traffic, enables secure cookies

---

## Problem

n8n is deployed with HTTP only, transmitting data in plain text.

---

## Solution

Install cert-manager and configure Let's Encrypt for automatic TLS certificate management.

---

## Implementation

### Step 1: Install cert-manager

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
```

### Step 2: Create ClusterIssuer

**File**: `manifests/tls/cluster-issuer-staging.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${CERT_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: alb
```

**File**: `manifests/tls/cluster-issuer-prod.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${CERT_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: alb
```

### Step 3: Update Ingress with TLS

**File**: `manifests/09-ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: n8n-ingress
  namespace: n8n
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/healthcheck-path: /healthz
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "10"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - ${N8N_DOMAIN}
    secretName: n8n-tls
  rules:
  - host: ${N8N_DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: n8n-service-simple
            port:
              number: 80
```

### Step 4: Update n8n Deployment for HTTPS

**File**: `manifests/06-n8n-deployment.yaml` (update env vars)

```yaml
        env:
        - name: N8N_SECURE_COOKIE
          value: "true"
        - name: N8N_PROTOCOL
          value: https
        - name: N8N_HOST
          value: ${N8N_DOMAIN}
        - name: WEBHOOK_URL
          value: https://${N8N_DOMAIN}/
```

### Step 5: Update Deployment Script

**File**: `scripts/deploy.sh` (add after EBS CSI driver)

```bash
# Install cert-manager
log_info "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
log_info "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager

# Prompt for certificate email
if [ -z "${CERT_EMAIL:-}" ]; then
    read -r -p "Enter email for Let's Encrypt certificates: " CERT_EMAIL
fi

# Create ClusterIssuers
log_info "Creating Let's Encrypt ClusterIssuers..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${CERT_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: alb
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${CERT_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: alb
EOF

log_success "cert-manager installed and configured"
```

### Step 6: Create Certificate Resource (Alternative to Ingress annotation)

**File**: `manifests/tls/certificate.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: n8n-tls
  namespace: n8n
spec:
  secretName: n8n-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - ${N8N_DOMAIN}
```

---

## Testing

### Test with Staging (Recommended First)

```bash
# Use staging issuer first
kubectl annotate ingress n8n-ingress -n n8n \
  cert-manager.io/cluster-issuer=letsencrypt-staging --overwrite

# Check certificate status
kubectl get certificate -n n8n
kubectl describe certificate n8n-tls -n n8n

# Check certificate secret
kubectl get secret n8n-tls -n n8n
```

### Switch to Production

```bash
# Delete staging certificate
kubectl delete certificate n8n-tls -n n8n
kubectl delete secret n8n-tls -n n8n

# Use production issuer
kubectl annotate ingress n8n-ingress -n n8n \
  cert-manager.io/cluster-issuer=letsencrypt-prod --overwrite

# Verify certificate
kubectl get certificate -n n8n
```

### Verify HTTPS Access

```bash
# Get ingress URL
INGRESS_URL=$(kubectl get ingress n8n-ingress -n n8n -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test HTTPS
curl -I https://${N8N_DOMAIN}

# Verify certificate
openssl s_client -connect ${N8N_DOMAIN}:443 -servername ${N8N_DOMAIN} < /dev/null
```

---

## DNS Configuration

Before deploying, configure DNS:

```bash
# Get ALB hostname
ALB_HOSTNAME=$(kubectl get ingress n8n-ingress -n n8n -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create CNAME record in Route53 (or your DNS provider)
aws route53 change-resource-record-sets \
  --hosted-zone-id ${HOSTED_ZONE_ID} \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"${N8N_DOMAIN}\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"${ALB_HOSTNAME}\"}]
      }
    }]
  }"
```

---

## Troubleshooting

### Certificate Not Issuing

```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate events
kubectl describe certificate n8n-tls -n n8n

# Check challenge status
kubectl get challenges -n n8n
kubectl describe challenge -n n8n
```

### Common Issues

**Issue**: HTTP-01 challenge fails
**Solution**: Ensure ALB is accessible on port 80 and DNS is configured

**Issue**: Rate limit exceeded
**Solution**: Use staging issuer first, then switch to production

**Issue**: Certificate not auto-renewing
**Solution**: Verify cert-manager is running and has proper permissions

---

## Certificate Renewal

Certificates auto-renew 30 days before expiration. Monitor with:

```bash
# Check certificate expiry
kubectl get certificate n8n-tls -n n8n -o jsonpath='{.status.notAfter}'

# Force renewal (if needed)
kubectl delete secret n8n-tls -n n8n
kubectl delete certificate n8n-tls -n n8n
kubectl apply -f manifests/tls/certificate.yaml
```

---

## Security Benefits

✅ All traffic encrypted with TLS 1.2+
✅ Automatic certificate renewal
✅ Secure cookies enabled
✅ HTTPS redirect enforced
✅ Free certificates from Let's Encrypt

---

## Cost Impact

- cert-manager: Free (open source)
- Let's Encrypt: Free
- **Total**: $0/month

---

## Alternative: AWS Certificate Manager (ACM)

For production, consider ACM:

```yaml
# Ingress annotation for ACM
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/id
```

Benefits:
- Managed by AWS
- No rate limits
- Automatic renewal
- Integration with ALB

---

**Status**: Ready to implement
**Dependencies**: cert-manager, DNS configuration, domain name
**Validation**: HTTPS access works, certificate is valid
