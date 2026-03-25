#!/bin/bash
set -euo pipefail

# Master deployment script for n8n on EKS
# Supports dev, test, and prod environments with different configurations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Default configuration
ENVIRONMENT="${ENVIRONMENT:-dev}"
CLUSTER_NAME="${CLUSTER_NAME:-n8n-cluster}"
REGION="${REGION:-ap-southeast-2}"
NAMESPACE="${NAMESPACE:-n8n}"

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy n8n on AWS EKS with environment-specific configurations.

OPTIONS:
    -e, --environment ENV    Environment: dev, test, or prod (default: dev)
    -c, --cluster NAME       Cluster name (default: n8n-cluster)
    -r, --region REGION      AWS region (default: ap-southeast-2)
    -h, --help              Show this help message

ENVIRONMENT CONFIGURATIONS:

  dev:
    - Single node (t3.small spot)
    - RDS: db.t3.micro
    - No Multi-AZ
    - No backups
    - Internal ALB
    - Cost: ~\$100/month

  test:
    - 2 nodes (t3.medium)
    - RDS: db.t3.small
    - No Multi-AZ
    - 7-day backups
    - Internal ALB
    - Cost: ~\$200/month

  prod:
    - 3 nodes (t3.medium)
    - RDS: db.t3.medium
    - Multi-AZ enabled
    - 30-day backups
    - Internal ALB
    - Auto-scaling enabled
    - Cost: ~\$400/month

REQUIRED ENVIRONMENT VARIABLES:
    DOMAIN              - Domain name (e.g., n8n.example.com)
    HOSTED_ZONE_ID      - Route53 hosted zone ID
    CORPORATE_CIDR      - Corporate network CIDR (e.g., 10.0.0.0/8)
    VPC_ID              - Existing VPC ID
    PRIVATE_SUBNETS     - Comma-separated subnet IDs

EXAMPLES:
    # Deploy dev environment
    ENVIRONMENT=dev DOMAIN=n8n-dev.example.com ./scripts/deploy-full.sh

    # Deploy production
    ENVIRONMENT=prod DOMAIN=n8n.example.com ./scripts/deploy-full.sh

    # Deploy to specific region
    ENVIRONMENT=test REGION=us-east-1 ./scripts/deploy-full.sh

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|test|prod)$ ]]; then
    error "Invalid environment: $ENVIRONMENT (must be dev, test, or prod)"
    exit 1
fi

# Validate required variables
if [ -z "${DOMAIN:-}" ]; then
    error "DOMAIN environment variable is required"
    exit 1
fi

if [ -z "${HOSTED_ZONE_ID:-}" ]; then
    error "HOSTED_ZONE_ID environment variable is required"
    exit 1
fi

if [ -z "${VPC_ID:-}" ]; then
    error "VPC_ID environment variable is required"
    exit 1
fi

if [ -z "${PRIVATE_SUBNETS:-}" ]; then
    error "PRIVATE_SUBNETS environment variable is required"
    exit 1
fi

CORPORATE_CIDR="${CORPORATE_CIDR:-10.0.0.0/8}"

print_header "n8n Full Deployment - ${ENVIRONMENT^^} Environment"

info "Configuration:"
echo "  Environment: $ENVIRONMENT"
echo "  Cluster: $CLUSTER_NAME"
echo "  Region: $REGION"
echo "  Domain: $DOMAIN"
echo "  VPC: $VPC_ID"
echo "  Corporate CIDR: $CORPORATE_CIDR"
echo ""

# Set environment-specific configurations
case $ENVIRONMENT in
    dev)
        NODE_TYPE="t3.small"
        NODE_COUNT=1
        NODE_MIN=1
        NODE_MAX=1
        USE_SPOT=true
        RDS_INSTANCE_CLASS="db.t3.micro"
        RDS_MULTI_AZ=false
        RDS_BACKUP_RETENTION=0
        ENABLE_HPA=false
        ;;
    test)
        NODE_TYPE="t3.medium"
        NODE_COUNT=2
        NODE_MIN=2
        NODE_MAX=3
        USE_SPOT=false
        RDS_INSTANCE_CLASS="db.t3.small"
        RDS_MULTI_AZ=false
        RDS_BACKUP_RETENTION=7
        ENABLE_HPA=false
        ;;
    prod)
        NODE_TYPE="t3.medium"
        NODE_COUNT=3
        NODE_MIN=3
        NODE_MAX=6
        USE_SPOT=false
        RDS_INSTANCE_CLASS="db.t3.medium"
        RDS_MULTI_AZ=true
        RDS_BACKUP_RETENTION=30
        ENABLE_HPA=true
        ;;
esac

info "Environment-specific settings:"
echo "  Node type: $NODE_TYPE"
echo "  Node count: $NODE_COUNT (min: $NODE_MIN, max: $NODE_MAX)"
echo "  Spot instances: $USE_SPOT"
echo "  RDS instance: $RDS_INSTANCE_CLASS"
echo "  RDS Multi-AZ: $RDS_MULTI_AZ"
echo "  RDS backups: $RDS_BACKUP_RETENTION days"
echo "  Auto-scaling: $ENABLE_HPA"
echo ""

# Confirm deployment
if [ "${AUTO_APPROVE:-false}" != "true" ]; then
    warning "This will create AWS resources that incur costs."
    read -p "Continue with deployment? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        info "Deployment cancelled"
        exit 0
    fi
fi

# Step 1: Create EKS cluster
print_header "Step 1: Creating EKS Cluster"

CLUSTER_CONFIG="/tmp/${CLUSTER_NAME}-config.yaml"
cat > "$CLUSTER_CONFIG" << EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${REGION}
  version: "1.34"

vpc:
  id: ${VPC_ID}
  subnets:
    private:
$(echo "$PRIVATE_SUBNETS" | tr ',' '\n' | while read subnet; do
    az=$(aws ec2 describe-subnets --subnet-ids $subnet --region $REGION --query 'Subnets[0].AvailabilityZone' --output text)
    cidr=$(aws ec2 describe-subnets --subnet-ids $subnet --region $REGION --query 'Subnets[0].CidrBlock' --output text)
    echo "      ${az}:"
    echo "        id: ${subnet}"
    echo "        cidr: ${cidr}"
done)

iam:
  withOIDC: true

managedNodeGroups:
  - name: ${CLUSTER_NAME}-workers
    instanceType: ${NODE_TYPE}
    desiredCapacity: ${NODE_COUNT}
    minSize: ${NODE_MIN}
    maxSize: ${NODE_MAX}
    privateNetworking: true
    volumeSize: 30
    volumeType: gp3
$([ "$USE_SPOT" = "true" ] && echo "    spot: true")
    labels:
      role: worker
      environment: ${ENVIRONMENT}
    tags:
      Environment: ${ENVIRONMENT}
      Project: n8n
      ManagedBy: eksctl

cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator", "controllerManager", "scheduler"]

addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: aws-ebs-csi-driver
    version: latest
    wellKnownPolicies:
      ebsCSIController: true
EOF

info "Creating EKS cluster (this takes 15-20 minutes)..."
eksctl create cluster -f "$CLUSTER_CONFIG"

success "EKS cluster created"

# Step 1.5: Configure proxy (if needed)
if [ -n "${PROXY_URL:-}" ]; then
    print_header "Step 1.5: Configuring Proxy on Nodes"
    
    export PROXY_URL
    "${SCRIPT_DIR}/configure-proxy.sh"
    
    success "Proxy configured"
fi

# Step 2: Create RDS
print_header "Step 2: Creating RDS PostgreSQL"

export DB_INSTANCE_CLASS="$RDS_INSTANCE_CLASS"
export MULTI_AZ="$RDS_MULTI_AZ"
export BACKUP_RETENTION="$RDS_BACKUP_RETENTION"

"${SCRIPT_DIR}/create-rds.sh"

success "RDS created"

# Step 3: Deploy n8n
print_header "Step 3: Deploying n8n Application"

info "Creating namespace..."
kubectl apply -f "${SCRIPT_DIR}/../manifests/00-namespace.yaml"

info "Creating owner credentials with random password..."
"${SCRIPT_DIR}/create-owner-secret-ssm.sh"

info "Deploying n8n..."
kubectl apply -f "${SCRIPT_DIR}/../manifests/06-n8n-deployment-rds.yaml"
kubectl apply -f "${SCRIPT_DIR}/../manifests/07-n8n-service.yaml"

if [ "$ENABLE_HPA" = "true" ]; then
    info "Enabling auto-scaling..."
    kubectl apply -f "${SCRIPT_DIR}/../manifests/08-hpa.yaml"
fi

info "Waiting for n8n pod to be ready..."
kubectl wait --for=condition=ready pod -l app=n8n -n n8n --timeout=300s

success "n8n deployed"

# Step 4: Create ALB with HTTPS
print_header "Step 4: Creating ALB with HTTPS"

export DOMAIN
export HOSTED_ZONE_ID
export CORPORATE_CIDR

"${SCRIPT_DIR}/create-alb-https.sh"

success "ALB created"

# Final summary
print_header "Deployment Complete!"

echo ""
success "Environment: ${ENVIRONMENT^^}"
success "Cluster: $CLUSTER_NAME"
success "Region: $REGION"
success "Access URL: https://$DOMAIN"
echo ""

info "Next steps:"
echo "  1. Access n8n at https://$DOMAIN"
echo "  2. Login with auto-generated credentials:"
echo "     Email: dl.it.cloudops@tweglobal.com"
echo "     Password: (retrieve from SSM)"
echo ""
echo "     To get password:"
echo "     aws ssm get-parameter --name /n8n/$CLUSTER_NAME/owner-password --with-decryption --region $REGION --query 'Parameter.Value' --output text"
echo ""
echo "  3. Create your first workflow"
echo ""

info "Monitoring:"
echo "  ./scripts/monitor.sh"
echo ""

info "Logs:"
echo "  ./scripts/get-logs.sh n8n"
echo ""

info "Backup:"
echo "  ./scripts/backup.sh"
echo ""

info "Cleanup:"
echo "  ./scripts/cleanup.sh"
