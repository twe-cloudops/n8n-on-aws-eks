# ECR Image Setup Instructions

**Purpose**: Push required container images to internal ECR for deployment in private subnets

**Issue**: ISSUE-000 - Container Image Pull Failure in Private Subnets

---

## Required Images

1. **PostgreSQL**: `postgres:15-alpine`
2. **n8n**: `n8nio/n8n:latest`

---

## Step 1: Create ECR Repositories

```bash
export AWS_PROFILE=test
export REGION=ap-southeast-2

# Create postgres repository
aws ecr create-repository \
  --repository-name n8n/postgres \
  --region $REGION \
  --profile $AWS_PROFILE

# Create n8n repository
aws ecr create-repository \
  --repository-name n8n/n8n \
  --region $REGION \
  --profile $AWS_PROFILE
```

---

## Step 2: Login to ECR

```bash
# Get ECR login password and login to Docker
aws ecr get-login-password --region $REGION --profile $AWS_PROFILE | \
  docker login --username AWS --password-stdin \
  308100948908.dkr.ecr.ap-southeast-2.amazonaws.com
```

---

## Step 3: Pull, Tag, and Push Images

### PostgreSQL Image

```bash
# Pull from Docker Hub
docker pull postgres:15-alpine

# Tag for ECR
docker tag postgres:15-alpine \
  308100948908.dkr.ecr.ap-southeast-2.amazonaws.com/n8n/postgres:15-alpine

# Push to ECR
docker push \
  308100948908.dkr.ecr.ap-southeast-2.amazonaws.com/n8n/postgres:15-alpine
```

### n8n Image

```bash
# Pull from Docker Hub
docker pull n8nio/n8n:latest

# Tag for ECR
docker tag n8nio/n8n:latest \
  308100948908.dkr.ecr.ap-southeast-2.amazonaws.com/n8n/n8n:latest

# Push to ECR
docker push \
  308100948908.dkr.ecr.ap-southeast-2.amazonaws.com/n8n/n8n:latest
```

---

## Step 4: Update Kubernetes Manifests

### Update PostgreSQL Deployment

Edit `manifests/03-postgres-deployment.yaml` line 16:

```yaml
# Change from:
image: postgres:15-alpine

# To:
image: 308100948908.dkr.ecr.ap-southeast-2.amazonaws.com/n8n/postgres:15-alpine
```

### Update n8n Deployment

Edit `manifests/06-n8n-deployment.yaml` line 24:

```yaml
# Change from:
image: n8nio/n8n:latest

# To:
image: 308100948908.dkr.ecr.ap-southeast-2.amazonaws.com/n8n/n8n:latest
```

---

## Step 5: Redeploy

```bash
# Delete existing deployments
kubectl delete deployment postgres-simple n8n-simple -n n8n

# Apply updated manifests
kubectl apply -f manifests/03-postgres-deployment.yaml
kubectl apply -f manifests/06-n8n-deployment.yaml

# Wait and verify
sleep 30
kubectl get pods -n n8n
```

---

## Step 6: Verify Deployment

```bash
# Check pod status (should be Running)
kubectl get pods -n n8n

# Check pod events
kubectl get events -n n8n --sort-by='.lastTimestamp' | tail -20

# Check n8n service and get NLB URL
kubectl get svc n8n-service-simple -n n8n

# Check pod logs
kubectl logs -n n8n -l app=n8n-simple --tail=50
```

---

## Troubleshooting

### If pods still can't pull images:

1. **Check ECR permissions**:
```bash
aws ecr describe-repositories --region $REGION --profile $AWS_PROFILE
```

2. **Verify node IAM role has ECR permissions**:
```bash
# Get node instance profile
kubectl get nodes -o wide

# Check IAM role attached to nodes
aws iam list-attached-role-policies \
  --role-name eksctl-n8n-cluster-nodegroup-ng-NodeInstanceRole-XXXXX \
  --region $REGION --profile $AWS_PROFILE
```

3. **Add ECR policy if missing**:
```bash
aws iam attach-role-policy \
  --role-name eksctl-n8n-cluster-nodegroup-ng-NodeInstanceRole-XXXXX \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly \
  --profile $AWS_PROFILE
```

---

## Alternative: Use VPC Endpoints (if ECR doesn't work)

If ECR still doesn't work, create VPC endpoints:

```bash
# Get VPC ID
export VPC_ID=vpc-0c6bc5a1488b5cfb0

# Get subnet IDs
export SUBNET_IDS="subnet-098c9a37ff83b4869,subnet-0a34ca141f76e8f2f,subnet-0e80caee7641da7b0"

# Get security group for nodes
export SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=*ClusterSharedNodeSecurityGroup*" \
  --query 'SecurityGroups[0].GroupId' --output text \
  --region $REGION --profile $AWS_PROFILE)

# Create ECR API endpoint
aws ec2 create-vpc-endpoint \
  --vpc-id $VPC_ID \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.ap-southeast-2.ecr.api \
  --subnet-ids $SUBNET_IDS \
  --security-group-ids $SG_ID \
  --region $REGION --profile $AWS_PROFILE

# Create ECR DKR endpoint
aws ec2 create-vpc-endpoint \
  --vpc-id $VPC_ID \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.ap-southeast-2.ecr.dkr \
  --subnet-ids $SUBNET_IDS \
  --security-group-ids $SG_ID \
  --region $REGION --profile $AWS_PROFILE

# Create S3 endpoint (for image layers)
aws ec2 create-vpc-endpoint \
  --vpc-id $VPC_ID \
  --vpc-endpoint-type Gateway \
  --service-name com.amazonaws.ap-southeast-2.s3 \
  --route-table-ids $(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'RouteTables[*].RouteTableId' --output text \
    --region $REGION --profile $AWS_PROFILE) \
  --region $REGION --profile $AWS_PROFILE
```

---

## Expected Result

After successful ECR setup and redeployment:

```
NAME                              READY   STATUS    RESTARTS   AGE
postgres-simple-xxxxxxxxx-xxxxx   1/1     Running   0          2m
n8n-simple-xxxxxxxxx-xxxxx        1/1     Running   0          2m
```

Then proceed to configure Route53 DNS record for n8n access.
