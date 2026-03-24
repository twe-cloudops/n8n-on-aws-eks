# Blueprint: Custom VPC and Subnet Selection

**Priority**: MEDIUM
**Effort**: 1-2 days
**Impact**: Enables deployment into existing VPCs, better network control

---

## Problem

Current deployment creates a new VPC automatically. Users need ability to deploy into existing VPCs with custom subnets.

---

## Solution

Add configuration options for custom VPC, subnets, and CIDR blocks.

---

## Implementation

### Step 1: Update Cluster Configuration Template

**File**: `infrastructure/cluster-config.yaml`

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${REGION}

# VPC Configuration
vpc:
  # Option 1: Use existing VPC
  id: "${VPC_ID}"  # Leave empty to create new VPC
  
  # Option 2: Create new VPC with custom CIDR
  cidr: "${VPC_CIDR:-10.0.0.0/16}"
  
  # NAT Gateway configuration
  nat:
    gateway: ${NAT_GATEWAY:-Single}  # Disable, Single, or HighlyAvailable
  
  # Subnet configuration
  subnets:
    # Public subnets (for NAT, Load Balancers)
    public:
      ${AZ1}:
        id: "${PUBLIC_SUBNET_1}"  # Leave empty to auto-create
        cidr: "${PUBLIC_SUBNET_1_CIDR:-10.0.0.0/19}"
      ${AZ2}:
        id: "${PUBLIC_SUBNET_2}"
        cidr: "${PUBLIC_SUBNET_2_CIDR:-10.0.32.0/19}"
      ${AZ3}:
        id: "${PUBLIC_SUBNET_3}"
        cidr: "${PUBLIC_SUBNET_3_CIDR:-10.0.64.0/19}"
    
    # Private subnets (for EKS nodes)
    private:
      ${AZ1}:
        id: "${PRIVATE_SUBNET_1}"
        cidr: "${PRIVATE_SUBNET_1_CIDR:-10.0.96.0/19}"
      ${AZ2}:
        id: "${PRIVATE_SUBNET_2}"
        cidr: "${PRIVATE_SUBNET_2_CIDR:-10.0.128.0/19}"
      ${AZ3}:
        id: "${PRIVATE_SUBNET_3}"
        cidr: "${PRIVATE_SUBNET_3_CIDR:-10.0.160.0/19}"
  
  # Cluster endpoints
  clusterEndpoints:
    publicAccess: ${PUBLIC_ACCESS:-true}
    privateAccess: ${PRIVATE_ACCESS:-true}

nodeGroups:
  - name: n8n-workers
    instanceType: ${INSTANCE_TYPE:-t3.medium}
    desiredCapacity: ${DESIRED_CAPACITY:-2}
    minSize: ${MIN_SIZE:-1}
    maxSize: ${MAX_SIZE:-4}
    
    # Subnet selection for nodes
    subnets: ${NODE_SUBNETS}  # Comma-separated subnet IDs or "private" for all private
    
    ssh:
      allow: false
    
    iam:
      withAddonPolicies:
        ebs: true
        cloudWatch: true
        imageBuilder: true
    
    volumeSize: 50
    volumeType: gp3
    volumeEncrypted: true
    
    # Node labels
    labels:
      workload: n8n
    
    # Node taints (optional)
    # taints:
    #   - key: workload
    #     value: n8n
    #     effect: NoSchedule

# Add-ons
addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
```

### Step 2: Create VPC Configuration Script

**File**: `scripts/configure-vpc.sh`

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
REGION="${REGION:-us-east-1}"
AWS_PROFILE="${AWS_PROFILE:-default}"
VPC_MODE="${VPC_MODE:-new}"  # new, existing, or custom

print_header "🌐 VPC Configuration"

# Function to list available VPCs
list_vpcs() {
    log_info "Available VPCs in ${REGION}:"
    aws ec2 describe-vpcs \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
        --output table
}

# Function to list subnets in VPC
list_subnets() {
    local vpc_id="$1"
    log_info "Subnets in VPC ${vpc_id}:"
    aws ec2 describe-subnets \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --filters "Name=vpc-id,Values=${vpc_id}" \
        --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
        --output table
}

# Interactive VPC selection
if [ "$VPC_MODE" = "existing" ]; then
    list_vpcs
    read -r -p "Enter VPC ID: " VPC_ID
    
    list_subnets "$VPC_ID"
    read -r -p "Enter private subnet IDs (comma-separated): " PRIVATE_SUBNETS
    read -r -p "Enter public subnet IDs (comma-separated): " PUBLIC_SUBNETS
    
    # Export for cluster config
    export VPC_ID
    export PRIVATE_SUBNETS
    export PUBLIC_SUBNETS
    export NODE_SUBNETS="$PRIVATE_SUBNETS"
    
elif [ "$VPC_MODE" = "custom" ]; then
    read -r -p "Enter VPC CIDR (default: 10.0.0.0/16): " VPC_CIDR
    VPC_CIDR="${VPC_CIDR:-10.0.0.0/16}"
    
    read -r -p "Enter NAT Gateway mode (Disable/Single/HighlyAvailable): " NAT_GATEWAY
    NAT_GATEWAY="${NAT_GATEWAY:-Single}"
    
    export VPC_CIDR
    export NAT_GATEWAY
    
else
    # New VPC with defaults
    log_info "Creating new VPC with default configuration"
    export VPC_CIDR="10.0.0.0/16"
    export NAT_GATEWAY="Single"
fi

log_success "VPC configuration complete"
```

### Step 3: Update Deployment Script

**File**: `scripts/deploy.sh` (add VPC configuration)

```bash
# VPC Configuration
log_info "Configuring VPC settings..."

# Check for existing VPC configuration
if [ -n "${VPC_ID:-}" ]; then
    log_info "Using existing VPC: $VPC_ID"
    VPC_CONFIG="id: \"$VPC_ID\""
    
    # Validate VPC exists
    if ! aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" --profile "$AWS_PROFILE" &>/dev/null; then
        error_exit "VPC $VPC_ID not found in region $REGION"
    fi
    
    # Get subnets if not provided
    if [ -z "${PRIVATE_SUBNETS:-}" ]; then
        log_info "Discovering private subnets in VPC..."
        PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
            --region "$REGION" \
            --profile "$AWS_PROFILE" \
            --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*private*" \
            --query 'Subnets[*].SubnetId' \
            --output text | tr '\t' ',')
    fi
    
    NODE_SUBNETS="$PRIVATE_SUBNETS"
else
    log_info "Creating new VPC with CIDR: ${VPC_CIDR:-10.0.0.0/16}"
    VPC_CONFIG="cidr: \"${VPC_CIDR:-10.0.0.0/16}\""
    NODE_SUBNETS="private"  # Use all private subnets
fi

# Create cluster config with VPC settings
cat > /tmp/cluster.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $CLUSTER_NAME
  region: $REGION

vpc:
  $VPC_CONFIG
  nat:
    gateway: ${NAT_GATEWAY:-Single}
  clusterEndpoints:
    publicAccess: ${PUBLIC_ACCESS:-true}
    privateAccess: ${PRIVATE_ACCESS:-true}

nodeGroups:
  - name: n8n-workers
    instanceType: ${INSTANCE_TYPE:-t3.medium}
    desiredCapacity: ${DESIRED_CAPACITY:-2}
    minSize: ${MIN_SIZE:-1}
    maxSize: ${MAX_SIZE:-4}
    subnets: [$NODE_SUBNETS]
    ssh:
      allow: false
    iam:
      withAddonPolicies:
        ebs: true
        cloudWatch: true
        imageBuilder: true
    volumeSize: 50
    volumeType: gp3
    volumeEncrypted: true
EOF

log_success "VPC configuration applied"
```

---

## Usage Examples

### Example 1: Deploy with Existing VPC

```bash
# Set VPC configuration
export VPC_ID="vpc-0123456789abcdef0"
export PRIVATE_SUBNETS="subnet-111,subnet-222,subnet-333"
export PUBLIC_SUBNETS="subnet-444,subnet-555,subnet-666"

# Deploy
./scripts/deploy.sh
```

### Example 2: Deploy with Custom VPC CIDR

```bash
# Set custom CIDR
export VPC_CIDR="172.16.0.0/16"
export NAT_GATEWAY="HighlyAvailable"

# Deploy
./scripts/deploy.sh
```

### Example 3: Interactive VPC Selection

```bash
# Run VPC configuration script
./scripts/configure-vpc.sh

# Then deploy
./scripts/deploy.sh
```

### Example 4: Private Cluster (No Public Access)

```bash
# Disable public access to cluster endpoint
export PUBLIC_ACCESS="false"
export PRIVATE_ACCESS="true"

# Deploy
./scripts/deploy.sh
```

---

## Validation

### Verify VPC Configuration

```bash
# Get cluster VPC
CLUSTER_VPC=$(aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --query 'cluster.resourcesVpcConfig.vpcId' \
    --output text)

echo "Cluster VPC: $CLUSTER_VPC"

# Get cluster subnets
aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --query 'cluster.resourcesVpcConfig.subnetIds' \
    --output table
```

### Verify Node Placement

```bash
# Check which subnets nodes are in
kubectl get nodes -o wide

# Get node subnet IDs
for node in $(kubectl get nodes -o name); do
    INSTANCE_ID=$(kubectl get "$node" -o jsonpath='{.spec.providerID}' | cut -d'/' -f5)
    SUBNET_ID=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --region "$REGION" \
        --query 'Reservations[0].Instances[0].SubnetId' \
        --output text)
    echo "$node: $SUBNET_ID"
done
```

---

## Network Requirements

### For Existing VPC

Ensure your VPC has:

✅ At least 2 availability zones
✅ Private subnets for EKS nodes
✅ Public subnets for Load Balancers (if using external NLB)
✅ NAT Gateway or NAT Instance (for private subnet internet access)
✅ VPC endpoints for AWS services (optional, for private clusters)

### Subnet Tagging

Tag subnets for automatic discovery:

```bash
# Tag private subnets
aws ec2 create-tags \
    --resources subnet-xxx \
    --tags Key=kubernetes.io/role/internal-elb,Value=1

# Tag public subnets
aws ec2 create-tags \
    --resources subnet-yyy \
    --tags Key=kubernetes.io/role/elb,Value=1

# Tag for cluster
aws ec2 create-tags \
    --resources subnet-xxx subnet-yyy \
    --tags Key=kubernetes.io/cluster/${CLUSTER_NAME},Value=shared
```

---

## Cost Considerations

### NAT Gateway Options

| Option | Cost | Use Case |
|--------|------|----------|
| Disable | $0 | Public subnets only |
| Single | ~$32/month | Development |
| HighlyAvailable | ~$96/month | Production (3 AZs) |

### VPC Endpoints (Optional)

For private clusters, add VPC endpoints to avoid NAT costs:

```bash
# S3 endpoint (free)
aws ec2 create-vpc-endpoint \
    --vpc-id "$VPC_ID" \
    --service-name com.amazonaws.${REGION}.s3 \
    --route-table-ids rtb-xxx

# ECR endpoint (~$7/month per AZ)
aws ec2 create-vpc-endpoint \
    --vpc-id "$VPC_ID" \
    --service-name com.amazonaws.${REGION}.ecr.api \
    --vpc-endpoint-type Interface \
    --subnet-ids subnet-xxx
```

---

## Troubleshooting

### Nodes Not Joining Cluster

```bash
# Check node security group
aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId'

# Verify subnet route tables have NAT gateway
aws ec2 describe-route-tables \
    --filters "Name=association.subnet-id,Values=subnet-xxx"
```

### Load Balancer Not Creating

```bash
# Check subnet tags
aws ec2 describe-subnets \
    --subnet-ids subnet-xxx \
    --query 'Subnets[*].Tags'

# Verify ALB controller has permissions
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

---

**Status**: Ready to implement
**Dependencies**: Existing VPC (optional), subnet IDs
**Validation**: Cluster deploys in specified VPC, nodes in correct subnets
