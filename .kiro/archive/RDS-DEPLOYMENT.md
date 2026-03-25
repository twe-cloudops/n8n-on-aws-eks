# Deploy n8n with RDS PostgreSQL

**Date**: 2026-03-25  
**Status**: Ready to deploy

---

## Step 1: Create RDS Instance

```bash
cd /mnt/c/Users/rohpow001/Documents/GitHub/n8n-on-aws-eks

# Set environment
export AWS_PROFILE=test
export REGION=ap-southeast-2
export VPC_ID=vpc-0c6bc5a1488b5cfb0
export PRIVATE_SUBNETS=subnet-098c9a37ff83b4869,subnet-0a34ca141f76e8f2f,subnet-0e80caee7641da7b0

# Create RDS instance (takes 5-10 minutes)
./scripts/create-rds.sh
```

**What it creates**:
- RDS PostgreSQL 16.6
- Instance: db.t3.micro (free tier eligible)
- Storage: 20GB encrypted (free tier)
- Backup: 7-day retention
- Network: Private subnets only
- Security group: Allows PostgreSQL from VPC
- Kubernetes secret: `n8n-postgres-rds`

---

## Step 2: Remove Old PostgreSQL Container

```bash
# Delete containerized PostgreSQL
kubectl delete deployment postgres-simple -n n8n
kubectl delete service postgres-service-simple -n n8n
```

---

## Step 3: Deploy n8n with RDS

```bash
# Set image variables
export N8N_IMAGE="993676232205.dkr.ecr.ap-southeast-2.amazonaws.com/twe-container-dockerhub/n8nio/n8n:2.11.0"

# Delete old n8n deployment
kubectl delete deployment n8n-simple -n n8n

# Deploy n8n with RDS connection
envsubst < manifests/06-n8n-deployment-rds.yaml | kubectl apply -f -

# Wait for pod
sleep 30
kubectl get pods -n n8n
```

---

## Step 4: Verify Deployment

```bash
# Check pod status
kubectl get pods -n n8n

# Check logs
kubectl logs -n n8n -l app=n8n --tail=50

# Check RDS connection
kubectl exec -n n8n -it deployment/n8n -- env | grep DB_POSTGRESDB
```

**Expected output**:
```
NAME                   READY   STATUS    RESTARTS   AGE
n8n-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

---

## Step 5: Get n8n URL

```bash
# Get LoadBalancer URL
kubectl get svc n8n-service-simple -n n8n

# Get NLB DNS
kubectl get svc n8n-service-simple -n n8n -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## RDS Management

### View RDS Details

```bash
aws rds describe-db-instances \
  --db-instance-identifier n8n-postgres \
  --region ap-southeast-2 \
  --profile test
```

### Get Connection Info

```bash
# From Kubernetes secret
kubectl get secret n8n-postgres-rds -n n8n -o jsonpath='{.data.host}' | base64 -d
kubectl get secret n8n-postgres-rds -n n8n -o jsonpath='{.data.username}' | base64 -d
```

### Connect to RDS (from pod)

```bash
kubectl run -it --rm psql \
  --image=postgres:16 \
  --restart=Never \
  --namespace=n8n \
  -- psql -h $(kubectl get secret n8n-postgres-rds -n n8n -o jsonpath='{.data.host}' | base64 -d) \
       -U $(kubectl get secret n8n-postgres-rds -n n8n -o jsonpath='{.data.username}' | base64 -d) \
       -d n8n
```

### Backup RDS

```bash
# Manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier n8n-postgres \
  --db-snapshot-identifier n8n-postgres-$(date +%Y%m%d-%H%M%S) \
  --region ap-southeast-2 \
  --profile test
```

### Scale RDS (for production)

```bash
# Upgrade to db.t3.small
aws rds modify-db-instance \
  --db-instance-identifier n8n-postgres \
  --db-instance-class db.t3.small \
  --apply-immediately \
  --region ap-southeast-2 \
  --profile test
```

---

## Cost Breakdown

### Free Tier (12 months)
- **Instance**: db.t3.micro - 750 hours/month (always free)
- **Storage**: 20GB - Free
- **Backups**: 20GB - Free
- **Total**: $0/month

### After Free Tier
- **Instance**: db.t3.micro - ~$15/month
- **Storage**: 20GB gp3 - ~$2/month
- **Backups**: 20GB - ~$2/month
- **Total**: ~$19/month

### Production (Recommended)
- **Instance**: db.t3.small - ~$30/month
- **Storage**: 50GB gp3 - ~$5/month
- **Backups**: 50GB - ~$5/month
- **Total**: ~$40/month

---

## Troubleshooting

### Pod can't connect to RDS

```bash
# Check security group
aws ec2 describe-security-groups \
  --group-names n8n-postgres-sg \
  --region ap-southeast-2 \
  --profile test

# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier n8n-postgres \
  --region ap-southeast-2 \
  --profile test \
  --query 'DBInstances[0].DBInstanceStatus'

# Test connection from pod
kubectl run -it --rm test-db \
  --image=postgres:16 \
  --restart=Never \
  --namespace=n8n \
  -- pg_isready -h <RDS_ENDPOINT> -U n8nuser
```

### RDS creation failed

```bash
# Check CloudFormation events
aws rds describe-events \
  --source-identifier n8n-postgres \
  --region ap-southeast-2 \
  --profile test

# Delete and recreate
aws rds delete-db-instance \
  --db-instance-identifier n8n-postgres \
  --skip-final-snapshot \
  --region ap-southeast-2 \
  --profile test
```

---

## Cleanup (if needed)

```bash
# Delete RDS instance
aws rds delete-db-instance \
  --db-instance-identifier n8n-postgres \
  --skip-final-snapshot \
  --region ap-southeast-2 \
  --profile test

# Delete subnet group
aws rds delete-db-subnet-group \
  --db-subnet-group-name n8n-postgres-subnet-group \
  --region ap-southeast-2 \
  --profile test

# Delete security group
aws ec2 delete-security-group \
  --group-name n8n-postgres-sg \
  --region ap-southeast-2 \
  --profile test

# Delete Kubernetes secret
kubectl delete secret n8n-postgres-rds -n n8n
```

---

## Benefits of RDS

✅ **Persistent**: Data survives pod/cluster failures  
✅ **Automated backups**: 7-day retention, point-in-time recovery  
✅ **High availability**: Multi-AZ failover (when enabled)  
✅ **Managed**: AWS handles patching, updates, monitoring  
✅ **Scalable**: Easy to resize instance and storage  
✅ **Secure**: Encrypted at rest, private subnets only  
✅ **Free tier**: 12 months free for testing  

---

**Ready to deploy!** 🚀
