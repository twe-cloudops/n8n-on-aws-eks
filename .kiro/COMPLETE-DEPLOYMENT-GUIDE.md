# Complete Deployment Guide - n8n on AWS EKS

**Version**: 2.2  
**Date**: 2026-03-25  
**Status**: ✅ Production Ready

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture](#architecture)
3. [All Issues Fixed](#all-issues-fixed)
4. [Environment Options](#environment-options)
5. [Deployment Steps](#deployment-steps)
6. [Configuration](#configuration)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance](#maintenance)

---

## Quick Start

### One-Command Deployment

```bash
# Development Environment
ENVIRONMENT=dev \
DOMAIN=n8n-dev.example.com \
HOSTED_ZONE_ID=Z123456789 \
VPC_ID=vpc-xxxxx \
PRIVATE_SUBNETS=subnet-a,subnet-b,subnet-c \
CORPORATE_CIDR=10.0.0.0/8 \
./scripts/deploy-full.sh

# Production Environment
ENVIRONMENT=prod \
DOMAIN=n8n.example.com \
HOSTED_ZONE_ID=Z123456789 \
VPC_ID=vpc-xxxxx \
PRIVATE_SUBNETS=subnet-a,subnet-b,subnet-c \
CORPORATE_CIDR=10.0.0.0/8 \
./scripts/deploy-full.sh
```

---

## Architecture

### Final Working Architecture

```
Corporate Network (10.0.0.0/8)
    ↓ HTTPS:443
Route53 DNS
    ↓
Internal ALB (Application Load Balancer)
    ├─ Security Group: 10.0.0.0/8:443, VPC CIDR:443
    ├─ TLS Termination (ACM Certificate)
    └─ HTTP Backend
        ↓
Target Group (HTTP)
    ↓ NodePort (32xxx)
EKS Worker Nodes
    ├─ Security Group: VPC CIDR:NodePort
    └─ Proxy: http://10.122.108.59:8080
        ↓
n8n Pod
    ├─ Image: ECR (993676232205...n8n:2.11.0)
    ├─ Proxy: HTTP_PROXY, HTTPS_PROXY
    └─ Database Connection
        ↓
RDS PostgreSQL 16.6
    ├─ Private Subnets
    ├─ SSL Enabled
    └─ Security Group: VPC CIDR:5432
```

### Key Components

- **ALB**: Application Load Balancer (not NLB) for HTTPS → HTTP support
- **ACM**: Certificate for HTTPS
- **Route53**: DNS management
- **EKS**: Kubernetes 1.34
- **RDS**: PostgreSQL 16.6 with SSL
- **ECR**: Internal container registry (993676232205)
- **Proxy**: Corporate proxy for internet access

---

## All Issues Fixed

### Issue 1: LoadBalancer Service Creating Classic LB ❌ → ✅

**Problem**:
- Kubernetes service with LoadBalancer type created Classic LB
- Variable substitution `${VAR}` in annotations didn't work
- Classic LB was internet-facing instead of internal
- No HTTPS support

**Root Cause**:
- Kubernetes doesn't process shell variable syntax
- AWS Load Balancer Controller not installed/working
- Service annotations ignored

**Solution**:
- Changed service type from `LoadBalancer` to `NodePort`
- Create ALB manually with proper configuration
- Use `scripts/create-alb-https.sh` for automation

**Files Changed**:
- `manifests/07-n8n-service.yaml`: Changed to NodePort

---

### Issue 2: NLB Doesn't Support HTTPS → HTTP ❌ → ✅

**Problem**:
- Initially tried NLB with TLS listener
- NLB terminates TLS but can only forward to TCP/TLS backends
- n8n serves HTTP, not HTTPS
- Result: "Empty reply from server"

**Root Cause**:
- NLB limitation: TLS termination only works with TCP/TLS backends
- Cannot do TLS → HTTP like ALB can

**Solution**:
- Switched from NLB to ALB
- ALB supports TLS termination with HTTP backends
- Created `scripts/create-alb-https.sh`

**Key Learning**:
- **Use ALB** for HTTPS → HTTP (web applications)
- **Use NLB** for TCP/TLS passthrough (high performance, non-HTTP)

---

### Issue 3: Image Variable Substitution ❌ → ✅

**Problem**:
- Deployment had `image: ${N8N_IMAGE:-...}`
- Kubernetes doesn't understand shell variable syntax
- Result: `InvalidImageName` error

**Root Cause**:
- Shell variable syntax in Kubernetes manifests not processed

**Solution**:
- Hardcoded ECR image path in manifest
- Use `sed` or `envsubst` in deployment scripts if variables needed

**Files Changed**:
- `manifests/06-n8n-deployment-rds.yaml`: Hardcoded ECR image

---

### Issue 4: Service Selector Mismatch ❌ → ✅

**Problem**:
- Service selector: `app: n8n-simple`
- Deployment label: `app: n8n`
- Service couldn't route to pods

**Root Cause**:
- Inconsistent labels between service and deployment

**Solution**:
- Updated service selector to `app: n8n`

**Files Changed**:
- `manifests/07-n8n-service.yaml`: Fixed selector

---

### Issue 5: Security Group Missing Corporate Network ❌ → ✅

**Problem**:
- ALB security group only allowed VPC CIDR (10.119.16.0/20)
- Corporate network (10.0.0.0/8) couldn't connect
- Result: Connection timeout

**Root Cause**:
- Didn't ask about network ranges
- Assumed VPC CIDR only

**Solution**:
- Added 10.0.0.0/8 to ALB security group inbound rules
- Made CORPORATE_CIDR a required parameter

**Key Learning**:
- **Always ask about network ranges** for internal load balancers
- Don't assume VPC CIDR only

---

### Issue 6: RDS SSL Connection Required ❌ → ✅

**Problem**:
- n8n couldn't connect to RDS
- Error: "no encryption"

**Root Cause**:
- RDS requires SSL by default
- Missing SSL environment variables in n8n deployment

**Solution**:
- Added SSL configuration:
  ```yaml
  - name: DB_POSTGRESDB_SSL_ENABLED
    value: "true"
  - name: DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED
    value: "false"
  ```

**Files Changed**:
- `manifests/06-n8n-deployment-rds.yaml`: Added SSL env vars

---

### Issue 7: n8n Registration Failed (No Internet) ❌ → ✅

**Problem**:
- Error: "Failed to register community edition: read ECONNRESET"
- n8n couldn't reach n8n.io for registration

**Root Cause**:
- n8n pod in private subnet without proxy configuration
- No internet access for external API calls

**Solution**:
- Added proxy environment variables to n8n pod:
  ```yaml
  - name: HTTP_PROXY
    value: "http://10.122.108.59:8080"
  - name: HTTPS_PROXY
    value: "http://10.122.108.59:8080"
  - name: NO_PROXY
    value: "localhost,127.0.0.1,169.254.169.254,.internal,.svc,.svc.cluster.local,10.119.16.0/20,.amazonaws.com"
  ```

**Files Changed**:
- `manifests/06-n8n-deployment-rds.yaml`: Added proxy env vars

**Enables**:
- Community edition registration
- Version notifications
- Workflow template downloads
- External integrations

---

### Issue 8: Container Image Pull from Public Registry ❌ → ✅

**Problem**:
- Nodes in private subnets couldn't pull from Docker Hub
- ImagePullBackOff errors

**Root Cause**:
- No internet access in private subnets
- No VPC endpoints for public registries

**Solution**:
- Use internal ECR (993676232205)
- Push images to ECR before deployment
- Configure manifests to use ECR images

**Images Used**:
- n8n: `993676232205.dkr.ecr.ap-southeast-2.amazonaws.com/twe-container-dockerhub/n8nio/n8n:2.11.0`
- PostgreSQL: `993676232205.dkr.ecr.ap-southeast-2.amazonaws.com/twe-container-dockerhub/library/postgres:16.6`

---

### Issue 9: Network Policy Invalid Field ❌ → ✅

**Problem**:
- Network policy had invalid `namespace` field in podSelector

**Root Cause**:
- Incorrect Kubernetes API syntax

**Solution**:
- Removed invalid namespace field from podSelector

**Files Changed**:
- `manifests/05-network-policy.yaml`: Fixed syntax

---

### Issue 10: PostgreSQL Security Vulnerabilities ❌ → ✅

**Problem**:
- postgres:15-alpine had known CVE vulnerabilities

**Solution**:
- Upgraded to PostgreSQL 16.6
- Latest stable version, addresses CVEs
- Compatible with n8n 2.0+

**Files Changed**:
- `manifests/03-postgres-deployment.yaml`: Updated image
- Migrated to RDS for production

---

## Environment Options

### Development (~$100/month)

```bash
ENVIRONMENT=dev
```

**Configuration**:
- Nodes: 1 x t3.small (spot instance)
- RDS: db.t3.micro
- Multi-AZ: No
- Backups: None
- Auto-scaling: No

**Use Case**: Testing, development, proof of concept

---

### Test (~$200/month)

```bash
ENVIRONMENT=test
```

**Configuration**:
- Nodes: 2 x t3.medium
- RDS: db.t3.small
- Multi-AZ: No
- Backups: 7 days
- Auto-scaling: No

**Use Case**: QA, staging, pre-production testing

---

### Production (~$400/month)

```bash
ENVIRONMENT=prod
```

**Configuration**:
- Nodes: 3 x t3.medium
- RDS: db.t3.medium
- Multi-AZ: Yes
- Backups: 30 days
- Auto-scaling: Yes (3-6 nodes)

**Use Case**: Production workloads, high availability

---

## Deployment Steps

### Prerequisites

1. **AWS CLI** configured with appropriate profile
2. **kubectl** installed (v1.28+)
3. **eksctl** installed (v0.150+)
4. **jq** installed
5. **AWS Permissions**: EKS, EC2, RDS, VPC, IAM, Route53, ACM, ELB

### Required Information

- **VPC ID**: Existing VPC
- **Private Subnets**: 3 subnets in different AZs
- **Domain**: DNS name for n8n
- **Hosted Zone ID**: Route53 zone
- **Corporate CIDR**: Network range (e.g., 10.0.0.0/8)
- **Proxy URL**: Corporate proxy (default: http://10.122.108.59:8080)

### Step 1: Clone Repository

```bash
git clone https://github.com/your-org/n8n-on-aws-eks.git
cd n8n-on-aws-eks
```

### Step 2: Set Environment Variables

```bash
export AWS_PROFILE=your-profile
export ENVIRONMENT=prod
export REGION=ap-southeast-2
export DOMAIN=n8n.example.com
export HOSTED_ZONE_ID=Z123456789
export VPC_ID=vpc-xxxxx
export PRIVATE_SUBNETS=subnet-a,subnet-b,subnet-c
export CORPORATE_CIDR=10.0.0.0/8
export PROXY_URL=http://10.122.108.59:8080  # Optional
```

### Step 3: Run Full Deployment

```bash
./scripts/deploy-full.sh
```

This will:
1. Create EKS cluster (15-20 minutes)
2. Create RDS PostgreSQL (5-10 minutes)
3. Deploy n8n application
4. Create ALB with HTTPS
5. Configure DNS

**Total Time**: ~25-30 minutes

### Step 4: Verify Deployment

```bash
# Check cluster
kubectl get nodes

# Check n8n
kubectl get pods -n n8n

# Check RDS
aws rds describe-db-instances --db-instance-identifier n8n-postgres

# Check ALB
aws elbv2 describe-load-balancers --names n8n-cluster-alb
```

### Step 5: Access n8n

Open browser: `https://your-domain.com`

---

## Configuration

### Automatic Owner Account Setup

Create owner account automatically on first startup:

```bash
kubectl create secret generic n8n-owner-credentials -n n8n \
  --from-literal=email='dl.it.cloudops@tweglobal.com' \
  --from-literal=password='YourSecurePassword123!' \
  --from-literal=first_name='TWE' \
  --from-literal=last_name='CloudOps'

kubectl rollout restart deployment/n8n -n n8n
```

**Security**: Delete secret after initial setup:
```bash
kubectl delete secret n8n-owner-credentials -n n8n
```

### Proxy Configuration

n8n pod already configured with proxy for:
- Community edition registration
- Version notifications
- Workflow template downloads
- External API integrations

**Default Proxy**: `http://10.122.108.59:8080`

**NO_PROXY**: VPC CIDR, AWS services, RDS endpoint

### SSL/TLS Configuration

- **ALB**: Terminates TLS with ACM certificate
- **RDS**: SSL enabled for database connections
- **n8n**: Serves HTTP internally (ALB handles HTTPS)

---

## Troubleshooting

### Issue: Can't Access n8n URL

**Check**:
1. Are you on corporate network (10.0.0.0/8)?
2. DNS resolving correctly?
   ```bash
   nslookup your-domain.com
   ```
3. ALB security group allows your network?
   ```bash
   aws ec2 describe-security-groups --group-ids sg-xxxxx
   ```

**Fix**:
```bash
# Add your network to ALB security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 443 \
  --cidr YOUR_CIDR
```

---

### Issue: n8n Pod Not Starting

**Check**:
```bash
kubectl describe pod -n n8n
kubectl logs -n n8n -l app=n8n
```

**Common Causes**:
1. Image pull failure → Check ECR access
2. Database connection → Check RDS security group
3. Resource limits → Check node capacity

---

### Issue: Database Connection Failed

**Check**:
1. RDS security group allows VPC CIDR on port 5432
2. SSL configuration in n8n deployment
3. RDS endpoint in secret

**Test Connection**:
```bash
kubectl run test-db --image=postgres:16 --rm -it --restart=Never -- \
  psql -h RDS_ENDPOINT -U n8nuser -d n8n
```

---

### Issue: Registration Failed

**Check**:
1. Proxy environment variables in n8n pod
2. NO_PROXY excludes RDS endpoint
3. Proxy accessible from pod

**Test Proxy**:
```bash
kubectl exec -it deployment/n8n -n n8n -- \
  curl -v -x http://10.122.108.59:8080 https://n8n.io
```

---

## Maintenance

### Monitoring

```bash
# Real-time monitoring
./scripts/monitor.sh --watch

# Check logs
./scripts/get-logs.sh n8n --follow

# Check metrics
kubectl top pods -n n8n
kubectl top nodes
```

### Backups

```bash
# Manual backup
./scripts/backup.sh

# Automated backups (RDS)
# Already configured with 7-30 day retention
```

### Updates

```bash
# Update n8n version
kubectl set image deployment/n8n n8n=NEW_IMAGE -n n8n

# Update cluster
eksctl upgrade cluster --name n8n-cluster

# Update node group
eksctl upgrade nodegroup --cluster n8n-cluster --name n8n-workers
```

### Scaling

```bash
# Scale nodes
eksctl scale nodegroup --cluster n8n-cluster --name n8n-workers --nodes 5

# Scale n8n pods (if HPA not enabled)
kubectl scale deployment n8n --replicas=3 -n n8n
```

### Cleanup

```bash
# Delete everything
./scripts/cleanup.sh

# Delete only n8n (keep cluster)
./scripts/cleanup.sh --namespace-only
```

---

## Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `deploy-full.sh` | Complete deployment | `ENVIRONMENT=prod ./scripts/deploy-full.sh` |
| `create-rds.sh` | Create RDS PostgreSQL | `./scripts/create-rds.sh` |
| `create-alb-https.sh` | Create ALB with HTTPS | `./scripts/create-alb-https.sh` |
| `monitor.sh` | Monitor deployment | `./scripts/monitor.sh --watch` |
| `backup.sh` | Backup database | `./scripts/backup.sh` |
| `restore.sh` | Restore database | `./scripts/restore.sh backup.sql.gz` |
| `get-logs.sh` | View logs | `./scripts/get-logs.sh n8n --follow` |
| `cleanup.sh` | Delete resources | `./scripts/cleanup.sh` |

---

## Files Reference

### Manifests

- `00-namespace.yaml`: Namespace with Pod Security Standards
- `00-proxy-config.yaml`: Proxy configuration (optional)
- `01-n8n-owner-secret.yaml`: Owner credentials (optional)
- `06-n8n-deployment-rds.yaml`: n8n deployment with RDS
- `07-n8n-service.yaml`: NodePort service
- `08-hpa.yaml`: Horizontal Pod Autoscaler (prod only)

### Infrastructure

- `entapps-npe-cluster-config.yaml`: Example cluster config
- `cluster-config.yaml`: Template cluster config

### Scripts

- All scripts in `scripts/` directory
- Common functions in `scripts/common.sh`

---

## Success Criteria

### Deployment Complete When:

- ✅ EKS cluster running with 2+ nodes
- ✅ RDS PostgreSQL available
- ✅ n8n pod running (1/1 Ready)
- ✅ ALB healthy targets
- ✅ HTTPS accessible from corporate network
- ✅ n8n registered with n8n.io
- ✅ Owner account created
- ✅ Test workflow created and saved

---

## Support

### Documentation

- `.kiro/COMPLETE-DEPLOYMENT-GUIDE.md`: This file
- `.kiro/FINAL-DEPLOYMENT-SUMMARY.md`: entapps-npe deployment
- `.kiro/EVERYTHING-FIXED.md`: All issues and fixes
- `README.md`: Project overview

### Example Deployment

**Account**: entapps-npe (777594735656)  
**URL**: https://n8n-cluster.001.ent-apps-npe-apse2.ent-apps-npe.twecloud.com  
**Status**: ✅ Working

---

## Version History

### v2.2 (2026-03-25)
- ✅ All issues fixed and documented
- ✅ ALB with HTTPS working
- ✅ Proxy support for n8n pod
- ✅ Automatic owner account setup
- ✅ Environment-based deployment (dev/test/prod)
- ✅ Complete automation scripts

### v2.1 (2026-03-25)
- RDS PostgreSQL integration
- Security enhancements
- Bug fixes

### v2.0 (2026-03-24)
- Code quality improvements
- Automated testing
- Enhanced scripts

---

**Status**: ✅ Production Ready  
**Last Updated**: 2026-03-25T15:53:00+11:00
