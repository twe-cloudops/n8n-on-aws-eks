#!/bin/bash
set -euo pipefail

# Create EFS for n8n persistent storage
# Cost-optimized: Uses Infrequent Access for non-prod environments

CLUSTER_NAME="${CLUSTER_NAME:-n8n-cluster}"
REGION="${REGION:-ap-southeast-2}"
AWS_PROFILE="${AWS_PROFILE:-default}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

echo "Creating EFS for n8n persistent storage..."
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"

# Get VPC ID from EKS cluster
VPC_ID=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text)

echo "VPC ID: $VPC_ID"

# Get subnet IDs
SUBNET_IDS=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --query 'cluster.resourcesVpcConfig.subnetIds' \
  --output text)

echo "Subnets: $SUBNET_IDS"

# Set lifecycle policy based on environment
if [ "$ENVIRONMENT" = "prod" ]; then
  LIFECYCLE_POLICY="AFTER_30_DAYS"
  PERFORMANCE_MODE="generalPurpose"
  THROUGHPUT_MODE="bursting"
  echo "Production: Standard storage, 30-day IA transition"
else
  LIFECYCLE_POLICY="AFTER_7_DAYS"
  PERFORMANCE_MODE="generalPurpose"
  THROUGHPUT_MODE="bursting"
  echo "Non-prod: Aggressive IA transition (7 days) for cost savings"
fi

# Create EFS file system
EFS_ID=$(aws efs create-file-system \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --performance-mode "$PERFORMANCE_MODE" \
  --throughput-mode "$THROUGHPUT_MODE" \
  --encrypted \
  --tags "Key=Name,Value=n8n-${CLUSTER_NAME}" \
         "Key=Environment,Value=${ENVIRONMENT}" \
         "Key=ManagedBy,Value=n8n-deployment" \
  --query 'FileSystemId' \
  --output text)

echo "✅ EFS created: $EFS_ID"

# Wait for EFS to be available
echo "Waiting for EFS to be available..."
aws efs describe-file-systems \
  --file-system-id "$EFS_ID" \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --query 'FileSystems[0].LifeCycleState' \
  --output text

while [ "$(aws efs describe-file-systems --file-system-id "$EFS_ID" --region "$REGION" --profile "$AWS_PROFILE" --query 'FileSystems[0].LifeCycleState' --output text)" != "available" ]; do
  echo "Waiting..."
  sleep 5
done

echo "✅ EFS available"

# Set lifecycle policy for cost optimization
aws efs put-lifecycle-configuration \
  --file-system-id "$EFS_ID" \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --lifecycle-policies "TransitionToIA=$LIFECYCLE_POLICY" \
  > /dev/null

echo "✅ Lifecycle policy set: $LIFECYCLE_POLICY"

# Create security group for EFS
SG_ID=$(aws ec2 create-security-group \
  --group-name "n8n-efs-${CLUSTER_NAME}" \
  --description "Security group for n8n EFS" \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --query 'GroupId' \
  --output text)

echo "✅ Security group created: $SG_ID"

# Get node security group
NODE_SG=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)

# Allow NFS from EKS nodes
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 2049 \
  --source-group "$NODE_SG" \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  > /dev/null

echo "✅ Security group rule added"

# Create mount targets in each subnet
for SUBNET_ID in $SUBNET_IDS; do
  echo "Creating mount target in subnet: $SUBNET_ID"
  aws efs create-mount-target \
    --file-system-id "$EFS_ID" \
    --subnet-id "$SUBNET_ID" \
    --security-groups "$SG_ID" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    > /dev/null || echo "Mount target may already exist"
done

echo "✅ Mount targets created"

# Output configuration
cat << EOF

========================================
EFS Configuration Complete
========================================

EFS ID: $EFS_ID
Security Group: $SG_ID
Lifecycle Policy: $LIFECYCLE_POLICY
Performance Mode: $PERFORMANCE_MODE

Cost Estimate (10GB):
EOF

if [ "$ENVIRONMENT" = "prod" ]; then
  echo "  Standard: ~\$3.60/month"
  echo "  After 30 days IA: ~\$0.45/month"
else
  echo "  Standard: ~\$3.60/month"
  echo "  After 7 days IA: ~\$0.45/month (aggressive cost savings)"
fi

cat << EOF

Next Steps:
1. Install EFS CSI driver:
   kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.7"

2. Create StorageClass and PVC:
   Update manifests/02-persistent-volumes.yaml with EFS_ID=$EFS_ID

3. Update n8n deployment to use EFS PVC

========================================
EOF
