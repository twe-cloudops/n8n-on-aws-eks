#!/bin/bash
# Deploy n8n on AWS EKS with enhanced security and custom VPC support
# Usage: ./deploy.sh [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-n8n-cluster}"
REGION="${REGION:-us-east-1}"
AWS_PROFILE="${AWS_PROFILE:-default}"

# VPC Configuration
VPC_ID="${VPC_ID:-}"
VPC_CIDR="${VPC_CIDR:-10.0.0.0/16}"
NAT_GATEWAY="${NAT_GATEWAY:-Single}"
PUBLIC_ACCESS="${PUBLIC_ACCESS:-true}"
PRIVATE_ACCESS="${PRIVATE_ACCESS:-true}"
PRIVATE_SUBNETS="${PRIVATE_SUBNETS:-}"
PUBLIC_SUBNETS="${PUBLIC_SUBNETS:-}"

# Load Balancer Configuration
LB_SCHEME="${LB_SCHEME:-internet-facing}"
LB_TYPE="${LB_TYPE:-nlb}"
LB_CROSS_ZONE="${LB_CROSS_ZONE:-true}"
LB_TARGET_TYPE="${LB_TARGET_TYPE:-ip}"

# Container Image Configuration
ECR_ACCOUNT_ID="${ECR_ACCOUNT_ID:-}"
ECR_REGION="${ECR_REGION:-${REGION}}"
N8N_IMAGE="${N8N_IMAGE:-n8nio/n8n:latest}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:16.6}"

# Security Configuration
CERT_EMAIL="${CERT_EMAIL:-}"
ENABLE_SECRETS_MANAGER="${ENABLE_SECRETS_MANAGER:-true}"
ENABLE_CERT_MANAGER="${ENABLE_CERT_MANAGER:-false}"
USE_ACM="${USE_ACM:-false}"
ACM_CERT_ARN="${ACM_CERT_ARN:-}"
N8N_DOMAIN="${N8N_DOMAIN:-}"

# Display help
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_usage "$(basename "$0")" "[options]"
    echo "Environment Variables:"
    echo "  CLUSTER_NAME              Cluster name (default: n8n-cluster)"
    echo "  REGION                    AWS region (default: us-east-1)"
    echo "  AWS_PROFILE               AWS profile (default: default)"
    echo ""
    echo "VPC Options:"
    echo "  VPC_ID                    Existing VPC ID (creates new if empty)"
    echo "  VPC_CIDR                  VPC CIDR (default: 10.0.0.0/16)"
    echo "  NAT_GATEWAY               NAT mode: Disable/Single/HighlyAvailable"
    echo "  PRIVATE_SUBNETS           Comma-separated private subnet IDs"
    echo "  PUBLIC_SUBNETS            Comma-separated public subnet IDs"
    echo ""
    echo "Container Image Options:"
    echo "  ECR_ACCOUNT_ID            AWS account ID for ECR (auto-detected if empty)"
    echo "  ECR_REGION                ECR region (default: same as REGION)"
    echo "  N8N_IMAGE                 n8n image (default: n8nio/n8n:latest)"
    echo "  POSTGRES_IMAGE            PostgreSQL image (default: postgres:15-alpine)"
    echo ""
    echo "Load Balancer Options:"
    echo "  LB_SCHEME                 internet-facing or internal (default: internet-facing)"
    echo "  LB_TYPE                   nlb or alb (default: nlb)"
    echo ""
    echo "Security Options:"
    echo "  ENABLE_SECRETS_MANAGER    Use AWS Secrets Manager (default: true)"
    echo "  ENABLE_CERT_MANAGER       Install cert-manager (default: false)"
    echo "  CERT_EMAIL                Email for Let's Encrypt certificates"
    echo "  USE_ACM                   Use AWS Certificate Manager (default: false)"
    echo "  ACM_CERT_ARN              ACM certificate ARN (required if USE_ACM=true)"
    echo "  N8N_DOMAIN                Domain name for n8n"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh"
    echo "  VPC_ID=vpc-xxx PRIVATE_SUBNETS=subnet-111,subnet-222 ./deploy.sh"
    echo "  LB_SCHEME=internal ./deploy.sh"
    echo "  ECR_ACCOUNT_ID=123456789012 N8N_IMAGE=123456789012.dkr.ecr.us-east-1.amazonaws.com/n8n:latest ./deploy.sh"
    exit 0
fi

print_header "🚀 n8n EKS Deployment (Enhanced)"

# Auto-detect ECR account ID if not provided
if [ -z "$ECR_ACCOUNT_ID" ]; then
    ECR_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text 2>/dev/null || echo "")
fi

# Build ECR image URLs if ECR_ACCOUNT_ID is set
if [ -n "$ECR_ACCOUNT_ID" ]; then
    # Only override if using default images
    if [ "$N8N_IMAGE" = "n8nio/n8n:latest" ]; then
        N8N_IMAGE="${ECR_ACCOUNT_ID}.dkr.ecr.${ECR_REGION}.amazonaws.com/n8n/n8n:latest"
    fi
    if [ "$POSTGRES_IMAGE" = "postgres:15-alpine" ]; then
        POSTGRES_IMAGE="${ECR_ACCOUNT_ID}.dkr.ecr.${ECR_REGION}.amazonaws.com/n8n/postgres:15-alpine"
    fi
fi

log_info "Configuration:"
echo "   Cluster: $CLUSTER_NAME"
echo "   Region: $REGION"
echo "   VPC: ${VPC_ID:-new}"
echo "   LB Scheme: $LB_SCHEME"
echo "   Secrets Manager: $ENABLE_SECRETS_MANAGER"
echo "   n8n Image: $N8N_IMAGE"
echo "   PostgreSQL Image: $POSTGRES_IMAGE"
echo ""

# Check prerequisites
log_info "Checking prerequisites..."
check_prerequisites aws kubectl eksctl || error_exit "Prerequisites check failed"
log_success "All required commands are available"

# Validate AWS
log_info "Validating AWS credentials..."
validate_aws_credentials "$AWS_PROFILE" || error_exit "AWS credentials validation failed"
validate_aws_region "$REGION" || error_exit "AWS region validation failed"
log_success "AWS validated"

# Check cluster exists
if check_cluster_exists "$CLUSTER_NAME" "$REGION" "$AWS_PROFILE"; then
    error_exit "Cluster '$CLUSTER_NAME' already exists"
fi

MANIFEST_DIR="${SCRIPT_DIR}/../manifests"

# VPC Configuration
log_info "Configuring VPC..."
if [ -n "$VPC_ID" ]; then
    log_info "Using existing VPC: $VPC_ID"
    VPC_CONFIG="id: \"$VPC_ID\""
    if [ -z "$PRIVATE_SUBNETS" ]; then
        PRIVATE_SUBNETS=$(aws ec2 describe-subnets --region "$REGION" --profile "$AWS_PROFILE" \
            --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*private*" \
            --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')
    fi
    NODE_SUBNETS="$PRIVATE_SUBNETS"
else
    log_info "Creating new VPC with CIDR: $VPC_CIDR"
    VPC_CONFIG="cidr: \"$VPC_CIDR\""
    NODE_SUBNETS="private"
fi

# Create cluster config
cat > /tmp/cluster.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: $CLUSTER_NAME
  region: $REGION
vpc:
  $VPC_CONFIG
  nat:
    gateway: $NAT_GATEWAY
  clusterEndpoints:
    publicAccess: $PUBLIC_ACCESS
    privateAccess: $PRIVATE_ACCESS
nodeGroups:
  - name: n8n-workers
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 1
    maxSize: 4
    subnets: [$NODE_SUBNETS]
    ssh:
      allow: false
    iam:
      withAddonPolicies:
        ebs: true
        cloudWatch: true
    volumeSize: 50
    volumeType: gp3
    volumeEncrypted: true
EOF

log_info "Creating EKS cluster..."
eksctl create cluster --config-file=/tmp/cluster.yaml --profile "$AWS_PROFILE" || error_exit "Cluster creation failed"
log_success "Cluster created"

# Update kubeconfig
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" --profile "$AWS_PROFILE"

# Install EBS CSI driver
log_info "Installing EBS CSI driver..."
aws eks create-addon --cluster-name "$CLUSTER_NAME" --addon-name aws-ebs-csi-driver \
    --region "$REGION" --profile "$AWS_PROFILE" 2>/dev/null || log_warning "EBS CSI addon may exist"
sleep 30

# Create storage class
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
EOF

# Install External Secrets Operator
if [ "$ENABLE_SECRETS_MANAGER" = "true" ]; then
    log_info "Installing External Secrets Operator..."
    kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml
    kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/external-secrets.yaml
    kubectl wait --for=condition=available --timeout=300s deployment/external-secrets -n external-secrets-system
    
    # Create secret in AWS
    DB_PASSWORD=$(openssl rand -base64 32)
    aws secretsmanager create-secret --name n8n/postgres-credentials \
        --secret-string "{\"username\":\"n8nuser\",\"password\":\"${DB_PASSWORD}\",\"database\":\"n8n\"}" \
        --region "$REGION" --profile "$AWS_PROFILE" 2>/dev/null || \
    aws secretsmanager update-secret --secret-id n8n/postgres-credentials \
        --secret-string "{\"username\":\"n8nuser\",\"password\":\"${DB_PASSWORD}\",\"database\":\"n8n\"}" \
        --region "$REGION" --profile "$AWS_PROFILE"
    
    # Create IAM service account
    eksctl create iamserviceaccount --name external-secrets --namespace external-secrets-system \
        --cluster "$CLUSTER_NAME" --region "$REGION" \
        --attach-policy-arn "arn:aws:iam::aws:policy/SecretsManagerReadWrite" \
        --approve --profile "$AWS_PROFILE" || log_warning "Service account may exist"
    
    log_success "Secrets Manager configured"
fi

# Install cert-manager
if [ "$ENABLE_CERT_MANAGER" = "true" ]; then
    log_info "Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
    
    if [ -n "$CERT_EMAIL" ]; then
        envsubst < "${MANIFEST_DIR}/tls/cluster-issuer-prod.yaml" | kubectl apply -f -
        log_success "cert-manager installed"
    fi
fi

# Deploy manifests
log_info "Deploying n8n..."
kubectl apply -f "${MANIFEST_DIR}/00-namespace.yaml"

if [ "$ENABLE_SECRETS_MANAGER" = "true" ]; then
    envsubst < "${MANIFEST_DIR}/secrets/secret-store.yaml" | kubectl apply -f -
    kubectl apply -f "${MANIFEST_DIR}/secrets/postgres-external-secret.yaml"
    kubectl wait --for=condition=Ready --timeout=60s externalsecret/postgres-credentials -n n8n
else
    kubectl apply -f "${MANIFEST_DIR}/01-postgres-secret.yaml"
fi

kubectl apply -f "${MANIFEST_DIR}/02-persistent-volumes.yaml"

# Apply deployments with image substitution
export N8N_IMAGE POSTGRES_IMAGE
envsubst < "${MANIFEST_DIR}/03-postgres-deployment.yaml" | kubectl apply -f -
kubectl apply -f "${MANIFEST_DIR}/04-postgres-service.yaml"
kubectl apply -f "${MANIFEST_DIR}/05-network-policy.yaml"
envsubst < "${MANIFEST_DIR}/06-n8n-deployment.yaml" | kubectl apply -f -

# Apply service with env substitution
export LB_SCHEME LB_TYPE LB_CROSS_ZONE LB_TARGET_TYPE
envsubst < "${MANIFEST_DIR}/07-n8n-service.yaml" | kubectl apply -f -

kubectl apply -f "${MANIFEST_DIR}/08-hpa.yaml"

# Apply ingress based on certificate method
if [ "$USE_ACM" = "true" ]; then
    if [ -z "$ACM_CERT_ARN" ]; then
        log_warning "USE_ACM=true but ACM_CERT_ARN not set, skipping ingress"
    else
        log_info "Applying ingress with ACM certificate..."
        export ACM_CERT_ARN N8N_DOMAIN LB_SCHEME
        envsubst < "${MANIFEST_DIR}/tls/ingress-acm.yaml" | kubectl apply -f -
    fi
elif [ "$ENABLE_CERT_MANAGER" = "true" ]; then
    log_info "Applying ingress with cert-manager..."
    kubectl apply -f "${MANIFEST_DIR}/09-ingress.yaml"
else
    log_info "Skipping ingress (no TLS configured)"
fi

# Wait for deployments
log_info "Waiting for deployments..."
kubectl wait --for=condition=available --timeout=600s deployment/postgres-simple -n n8n 2>/dev/null || log_warning "PostgreSQL still initializing"
kubectl wait --for=condition=available --timeout=600s deployment/n8n-simple -n n8n 2>/dev/null || log_warning "n8n still initializing"

echo ""
log_success "Deployment complete!"
kubectl get pods -n n8n
echo ""
kubectl get services -n n8n

rm -f /tmp/cluster.yaml
log_success "Setup completed!"

addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
EOF

log_info "Creating EKS cluster (this may take 15-20 minutes)..."
if ! eksctl create cluster --config-file=/tmp/cluster.yaml --profile "$AWS_PROFILE"; then
    rm -f /tmp/cluster.yaml
    error_exit "Failed to create EKS cluster"
fi

log_success "Cluster created successfully!"

# Update kubeconfig
log_info "Updating kubeconfig..."
if ! aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" --profile "$AWS_PROFILE"; then
    error_exit "Failed to update kubeconfig"
fi
log_success "Kubeconfig updated"

# Install EBS CSI driver
log_info "Installing EBS CSI driver addon..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)

if ! aws eks create-addon \
    --cluster-name "$CLUSTER_NAME" \
    --addon-name aws-ebs-csi-driver \
    --region "$REGION" \
    --profile "$AWS_PROFILE" 2>/dev/null; then
    log_warning "EBS CSI driver addon might already exist or failed. Continuing..."
else
    log_success "EBS CSI driver addon created"
fi

# Wait for addon to be ready
log_info "Waiting for EBS CSI driver to be ready..."
sleep 30

# Create storage class if it doesn't exist
if ! kubectl get storageclass gp3 &>/dev/null; then
    log_info "Creating gp3 storage class..."
    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
EOF
    log_success "Storage class created"
else
    log_info "Storage class gp3 already exists"
fi

# Deploy n8n manifests in order
log_info "Deploying n8n manifests..."

# Define manifest files in deployment order
MANIFEST_FILES=(
    "00-namespace.yaml"
    "01-postgres-secret.yaml"
    "02-persistent-volumes.yaml"
    "03-postgres-deployment.yaml"
    "04-postgres-service.yaml"
    "05-network-policy.yaml"
    "06-n8n-deployment.yaml"
    "07-n8n-service.yaml"
    "08-hpa.yaml"
    "09-ingress.yaml"
    "10-backup-cronjob.yaml"
    "11-restore-job.yaml"
)

for manifest in "${MANIFEST_FILES[@]}"; do
    manifest_path="${MANIFEST_DIR}/${manifest}"
    if [ -f "$manifest_path" ]; then
        log_info "Applying $manifest..."
        kubectl apply -f "$manifest_path" || log_warning "Failed to apply $manifest, continuing..."
    else
        log_warning "Manifest not found: $manifest (skipping)"
    fi
done

log_success "Manifests deployed"

# Wait for PVCs to be bound
log_info "Waiting for persistent volumes to be ready..."
if ! kubectl wait --for=condition=Bound --timeout=300s pvc/postgres-pvc -n n8n 2>/dev/null; then
    log_warning "PostgreSQL PVC binding may still be in progress"
fi
if ! kubectl wait --for=condition=Bound --timeout=300s pvc/n8n-pvc -n n8n 2>/dev/null; then
    log_warning "n8n PVC binding may still be in progress"
fi

# Wait for deployments
log_info "Waiting for deployments to be ready (this may take several minutes)..."
if ! kubectl wait --for=condition=available --timeout=600s deployment/postgres-simple -n n8n 2>/dev/null; then
    log_warning "PostgreSQL deployment still initializing"
fi
if ! kubectl wait --for=condition=available --timeout=600s deployment/n8n-simple -n n8n 2>/dev/null; then
    log_warning "n8n deployment still initializing"
fi

echo ""
log_success "Deployment complete!"
echo ""

log_info "Current Status:"
print_separator
kubectl get pods -n n8n
echo ""

log_info "Services:"
print_separator
kubectl get services -n n8n
echo ""

log_info "Storage:"
print_separator
kubectl get pvc -n n8n
echo ""

log_info "n8n Access URL:"
print_separator
N8N_URL=$(kubectl get service n8n-service-simple -n n8n -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$N8N_URL" ]; then
    echo "   http://${N8N_URL}"
else
    echo "   LoadBalancer URL is pending, please wait a few minutes..."
fi
echo ""

log_info "Next Steps:"
print_separator
echo "   1. Monitor deployment: ./scripts/monitor.sh"
echo "   2. View logs: ./scripts/get-logs.sh"
echo "   3. Create backup: ./scripts/backup.sh"
echo ""

# Cleanup temp file
rm -f /tmp/cluster.yaml

log_success "Setup completed successfully!"
