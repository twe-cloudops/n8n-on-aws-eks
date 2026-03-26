# Blueprint: Configurable Network Load Balancer

**Priority**: MEDIUM
**Effort**: 1 day
**Impact**: Enables internal-only deployments, better network control

---

## Problem

Current NLB is always internet-facing. Users need option for internal-only load balancers.

---

## Solution

Add configuration options for NLB scheme (internal/external), cross-zone load balancing, and other NLB settings.

---

## Implementation

### Step 1: Create Configurable Service Manifest

**File**: `manifests/07-n8n-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: n8n-service-simple
  namespace: n8n
  labels:
    app: n8n
  annotations:
    # Load Balancer Type
    service.beta.kubernetes.io/aws-load-balancer-type: "${LB_TYPE:-nlb}"
    
    # Load Balancer Scheme (internet-facing or internal)
    service.beta.kubernetes.io/aws-load-balancer-scheme: "${LB_SCHEME:-internet-facing}"
    
    # Cross-Zone Load Balancing
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "${LB_CROSS_ZONE:-true}"
    
    # Subnet Selection (optional - for internal LB)
    # service.beta.kubernetes.io/aws-load-balancer-subnets: "${LB_SUBNETS}"
    
    # Access Logs (optional)
    # service.beta.kubernetes.io/aws-load-balancer-access-log-enabled: "true"
    # service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-name: "${LB_LOG_BUCKET}"
    
    # Connection Settings
    service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "${LB_IDLE_TIMEOUT:-60}"
    
    # Target Group Settings
    service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: "deregistration_delay.timeout_seconds=${LB_DEREGISTER_DELAY:-30}"
    
    # Health Check Settings
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "HTTP"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "5678"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/healthz"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "${LB_HC_INTERVAL:-10}"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: "${LB_HC_TIMEOUT:-5}"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "${LB_HC_HEALTHY:-2}"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "${LB_HC_UNHEALTHY:-2}"
    
    # IP Mode (for NLB)
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "${LB_TARGET_TYPE:-ip}"
    
    # Proxy Protocol (optional)
    # service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*"
    
    # SSL/TLS (optional - for NLB with TLS termination)
    # service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${LB_SSL_CERT_ARN}"
    # service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
    # service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
    
    # Tags
    service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: "Environment=${ENVIRONMENT:-production},ManagedBy=n8n-eks"

spec:
  type: LoadBalancer
  ports:
  - port: ${LB_PORT:-80}
    targetPort: 5678
    protocol: TCP
    name: http
  selector:
    app: n8n
```

### Step 2: Create Service Configuration Script

**File**: `scripts/configure-service.sh`

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

print_header "⚖️  Load Balancer Configuration"

# Default values
LB_SCHEME="${LB_SCHEME:-internet-facing}"
LB_TYPE="${LB_TYPE:-nlb}"
LB_CROSS_ZONE="${LB_CROSS_ZONE:-true}"
LB_TARGET_TYPE="${LB_TARGET_TYPE:-ip}"

# Interactive configuration
if [ "${INTERACTIVE:-false}" = "true" ]; then
    echo "Load Balancer Configuration:"
    echo ""
    
    # Scheme selection
    echo "1. Load Balancer Scheme:"
    echo "   a) internet-facing (public access)"
    echo "   b) internal (private VPC only)"
    read -r -p "Select scheme (a/b) [a]: " scheme_choice
    
    case "${scheme_choice:-a}" in
        b) LB_SCHEME="internal" ;;
        *) LB_SCHEME="internet-facing" ;;
    esac
    
    # Type selection
    echo ""
    echo "2. Load Balancer Type:"
    echo "   a) nlb (Network Load Balancer - Layer 4)"
    echo "   b) alb (Application Load Balancer - Layer 7)"
    read -r -p "Select type (a/b) [a]: " type_choice
    
    case "${type_choice:-a}" in
        b) LB_TYPE="alb" ;;
        *) LB_TYPE="nlb" ;;
    esac
    
    # Cross-zone load balancing
    echo ""
    read -r -p "Enable cross-zone load balancing? (y/n) [y]: " cross_zone
    case "${cross_zone:-y}" in
        n|N) LB_CROSS_ZONE="false" ;;
        *) LB_CROSS_ZONE="true" ;;
    esac
    
    # Subnet selection for internal LB
    if [ "$LB_SCHEME" = "internal" ]; then
        echo ""
        echo "For internal load balancer, specify subnets (optional):"
        read -r -p "Enter subnet IDs (comma-separated) or press Enter to auto-select: " LB_SUBNETS
        export LB_SUBNETS
    fi
fi

# Export configuration
export LB_SCHEME
export LB_TYPE
export LB_CROSS_ZONE
export LB_TARGET_TYPE

log_success "Load Balancer configuration:"
echo "  Scheme: $LB_SCHEME"
echo "  Type: $LB_TYPE"
echo "  Cross-Zone: $LB_CROSS_ZONE"
echo "  Target Type: $LB_TARGET_TYPE"
[ -n "${LB_SUBNETS:-}" ] && echo "  Subnets: $LB_SUBNETS"
```

### Step 3: Update Deployment Script

**File**: `scripts/deploy.sh` (add before applying manifests)

```bash
# Load Balancer Configuration
log_info "Configuring Load Balancer settings..."

# Set defaults if not provided
LB_SCHEME="${LB_SCHEME:-internet-facing}"
LB_TYPE="${LB_TYPE:-nlb}"
LB_CROSS_ZONE="${LB_CROSS_ZONE:-true}"
LB_TARGET_TYPE="${LB_TARGET_TYPE:-ip}"

log_info "Load Balancer Configuration:"
echo "  Scheme: $LB_SCHEME"
echo "  Type: $LB_TYPE"

# For internal LB, ensure subnets are tagged
if [ "$LB_SCHEME" = "internal" ]; then
    log_warning "Using internal load balancer - ensure subnets are tagged with:"
    echo "  kubernetes.io/role/internal-elb=1"
    
    # Auto-discover internal subnets if not specified
    if [ -z "${LB_SUBNETS:-}" ] && [ -n "${VPC_ID:-}" ]; then
        log_info "Auto-discovering internal subnets..."
        LB_SUBNETS=$(aws ec2 describe-subnets \
            --region "$REGION" \
            --profile "$AWS_PROFILE" \
            --filters "Name=vpc-id,Values=$VPC_ID" \
                      "Name=tag:kubernetes.io/role/internal-elb,Values=1" \
            --query 'Subnets[*].SubnetId' \
            --output text | tr '\t' ',')
        
        if [ -n "$LB_SUBNETS" ]; then
            log_success "Found internal subnets: $LB_SUBNETS"
            export LB_SUBNETS
        fi
    fi
fi

# Apply service manifest with substitutions
log_info "Applying n8n service with Load Balancer configuration..."
envsubst < "${MANIFEST_DIR}/07-n8n-service.yaml" | kubectl apply -f -
```

### Step 4: Create Service Variants

**File**: `manifests/services/n8n-service-internal.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: n8n-service-internal
  namespace: n8n
  labels:
    app: n8n
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internal"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 5678
    protocol: TCP
    name: http
  selector:
    app: n8n
```

**File**: `manifests/services/n8n-service-external.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: n8n-service-external
  namespace: n8n
  labels:
    app: n8n
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 5678
    protocol: TCP
    name: http
  selector:
    app: n8n
```

---

## Usage Examples

### Example 1: Internal Load Balancer

```bash
# Deploy with internal NLB
export LB_SCHEME="internal"
./scripts/deploy.sh
```

### Example 2: External Load Balancer (Default)

```bash
# Deploy with internet-facing NLB
export LB_SCHEME="internet-facing"
./scripts/deploy.sh
```

### Example 3: Application Load Balancer

```bash
# Use ALB instead of NLB
export LB_TYPE="alb"
export LB_SCHEME="internet-facing"
./scripts/deploy.sh
```

### Example 4: Internal with Specific Subnets

```bash
# Internal NLB in specific subnets
export LB_SCHEME="internal"
export LB_SUBNETS="subnet-111,subnet-222"
./scripts/deploy.sh
```

### Example 5: Interactive Configuration

```bash
# Run interactive configuration
export INTERACTIVE="true"
./scripts/configure-service.sh

# Then deploy
./scripts/deploy.sh
```

---

## Subnet Tagging

### For Internal Load Balancers

Tag private subnets:

```bash
# Tag subnets for internal ELB
aws ec2 create-tags \
    --resources subnet-xxx subnet-yyy subnet-zzz \
    --tags Key=kubernetes.io/role/internal-elb,Value=1 \
    --region "$REGION"
```

### For External Load Balancers

Tag public subnets:

```bash
# Tag subnets for external ELB
aws ec2 create-tags \
    --resources subnet-aaa subnet-bbb subnet-ccc \
    --tags Key=kubernetes.io/role/elb,Value=1 \
    --region "$REGION"
```

---

## Validation

### Verify Load Balancer Configuration

```bash
# Get service details
kubectl describe service n8n-service-simple -n n8n

# Get load balancer ARN
LB_ARN=$(kubectl get service n8n-service-simple -n n8n \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' | \
    xargs -I {} aws elbv2 describe-load-balancers \
    --region "$REGION" \
    --query "LoadBalancers[?DNSName=='{}'].LoadBalancerArn" \
    --output text)

# Check load balancer scheme
aws elbv2 describe-load-balancers \
    --load-balancer-arns "$LB_ARN" \
    --region "$REGION" \
    --query 'LoadBalancers[0].Scheme' \
    --output text

# Check subnets
aws elbv2 describe-load-balancers \
    --load-balancer-arns "$LB_ARN" \
    --region "$REGION" \
    --query 'LoadBalancers[0].AvailabilityZones[*].[ZoneName,SubnetId]' \
    --output table
```

### Test Connectivity

**For Internal Load Balancer:**

```bash
# From within VPC (e.g., bastion host or another pod)
LB_DNS=$(kubectl get service n8n-service-simple -n n8n \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl -I http://${LB_DNS}
```

**For External Load Balancer:**

```bash
# From anywhere
LB_DNS=$(kubectl get service n8n-service-simple -n n8n \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl -I http://${LB_DNS}
```

---

## Advanced Configurations

### TLS Termination at NLB

```yaml
annotations:
  service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:region:account:certificate/id"
  service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
  service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"

spec:
  ports:
  - port: 443
    targetPort: 5678
    protocol: TCP
    name: https
```

### Access Logs

```yaml
annotations:
  service.beta.kubernetes.io/aws-load-balancer-access-log-enabled: "true"
  service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-name: "my-lb-logs"
  service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-prefix: "n8n"
```

### Proxy Protocol

```yaml
annotations:
  service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*"
```

### Static IP (Elastic IP)

```yaml
annotations:
  service.beta.kubernetes.io/aws-load-balancer-eip-allocations: "eipalloc-xxx,eipalloc-yyy"
```

---

## Cost Comparison

### Network Load Balancer

| Configuration | Monthly Cost (us-east-1) |
|---------------|--------------------------|
| Basic NLB | ~$16.43 |
| NLB + Cross-Zone | ~$16.43 + data transfer |
| NLB + TLS | ~$16.43 |
| NLB + Access Logs | ~$16.43 + S3 storage |

### Application Load Balancer

| Configuration | Monthly Cost (us-east-1) |
|---------------|--------------------------|
| Basic ALB | ~$22.50 |
| ALB + TLS | ~$22.50 |
| ALB + WAF | ~$27.50 + rules |

**Note**: NLB is cheaper and better for Layer 4 traffic. ALB provides Layer 7 features (path-based routing, WAF).

---

## Troubleshooting

### Load Balancer Not Creating

```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check service events
kubectl describe service n8n-service-simple -n n8n

# Verify subnet tags
aws ec2 describe-subnets \
    --subnet-ids subnet-xxx \
    --query 'Subnets[*].Tags'
```

### Internal LB Not Accessible

```bash
# Verify security groups
aws elbv2 describe-load-balancers \
    --load-balancer-arns "$LB_ARN" \
    --query 'LoadBalancers[0].SecurityGroups'

# Check target health
aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN"
```

### Cross-Zone Not Working

```bash
# Verify cross-zone setting
aws elbv2 describe-load-balancer-attributes \
    --load-balancer-arn "$LB_ARN" \
    --query 'Attributes[?Key==`load_balancing.cross_zone.enabled`]'
```

---

## Migration Guide

### From External to Internal

```bash
# 1. Update service annotation
kubectl annotate service n8n-service-simple -n n8n \
    service.beta.kubernetes.io/aws-load-balancer-scheme=internal --overwrite

# 2. Delete and recreate service
kubectl delete service n8n-service-simple -n n8n
kubectl apply -f manifests/services/n8n-service-internal.yaml

# 3. Update DNS to point to new internal LB
```

### From Internal to External

```bash
# 1. Update service annotation
kubectl annotate service n8n-service-simple -n n8n \
    service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing --overwrite

# 2. Delete and recreate service
kubectl delete service n8n-service-simple -n n8n
kubectl apply -f manifests/services/n8n-service-external.yaml

# 3. Update DNS to point to new external LB
```

---

**Status**: Ready to implement
**Dependencies**: AWS Load Balancer Controller, properly tagged subnets
**Validation**: Load balancer created with correct scheme, accessible as expected
