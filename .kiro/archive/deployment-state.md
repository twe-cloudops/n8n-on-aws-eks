# Current Deployment State - Quick Reference

**Last Updated**: 2026-03-25T11:18:00+11:00

---

## AWS Environment

```bash
export AWS_PROFILE=test
export REGION=ap-southeast-2
export CLUSTER_NAME=n8n-cluster
export VPC_ID=vpc-0c6bc5a1488b5cfb0
export PRIVATE_SUBNETS=subnet-098c9a37ff83b4869,subnet-0a34ca141f76e8f2f,subnet-0e80caee7641da7b0
export LB_SCHEME=internal
export N8N_DOMAIN=n8n-cluster.001.enc-test-shared.enc-test.twecloud.com
export http_proxy=http://10.122.108.59:8080
export https_proxy=http://10.122.108.59:8080
export NO_PROXY=".internal,.compute.internal,10.117.0.0/16,169.254.169.254,.amazonaws.com"
```

---

## Cluster Status

**Account**: enc-test (308100948908)  
**Region**: ap-southeast-2  
**Cluster**: n8n-cluster  
**Kubernetes**: 1.34  
**Nodes**: 2 x t3.medium (Ready)  
**VPC**: vpc-0c6bc5a1488b5cfb0 (enc-test-shared-001)  
**Subnets**: Private only (3 AZs)

---

## Deployment Status

### Namespace: n8n
- Status: ✅ Created
- PSS: baseline (relaxed for testing)
- Resource quota: Applied

### Services
- `postgres-service-simple`: ✅ ClusterIP (172.20.64.149:5432)
- `n8n-service-simple`: ✅ LoadBalancer (internal NLB, pending)

### Deployments
- `postgres-simple`: ⚠️ ImagePullBackOff
- `n8n-simple`: ⚠️ ContainerCreating

### Secrets
- `postgres-secret`: ✅ Created (hardcoded credentials)

---

## Current Blocker

**ISSUE-000**: Container Image Pull Failure

**Problem**: Nodes in private subnets cannot pull images from Docker Hub

**Images Needed**:
- postgres:15-alpine
- n8nio/n8n:latest

**Solution**: Push to internal ECR

**Instructions**: See `.kiro/ecr-setup.md`

---

## Quick Commands

### Check Cluster
```bash
kubectl cluster-info
kubectl get nodes
```

### Check n8n Namespace
```bash
kubectl get all -n n8n
kubectl get events -n n8n --sort-by='.lastTimestamp' | tail -20
```

### Check Pods
```bash
kubectl get pods -n n8n
kubectl describe pod -n n8n <pod-name>
kubectl logs -n n8n <pod-name>
```

### Check Services
```bash
kubectl get svc -n n8n
kubectl describe svc n8n-service-simple -n n8n
```

### Redeploy After ECR Setup
```bash
kubectl delete deployment postgres-simple n8n-simple -n n8n
kubectl apply -f manifests/03-postgres-deployment.yaml
kubectl apply -f manifests/06-n8n-deployment.yaml
```

---

## Files to Update for ECR

1. **manifests/03-postgres-deployment.yaml** (line 16)
   ```yaml
   image: 308100948908.dkr.ecr.ap-southeast-2.amazonaws.com/n8n/postgres:15-alpine
   ```

2. **manifests/06-n8n-deployment.yaml** (line 24)
   ```yaml
   image: 308100948908.dkr.ecr.ap-southeast-2.amazonaws.com/n8n/n8n:latest
   ```

---

## Next Steps

1. ✅ Documentation updated
2. **NEXT**: User pushes images to ECR (see `.kiro/ecr-setup.md`)
3. Update manifests with ECR image paths
4. Redeploy
5. Verify pods running
6. Get NLB URL
7. Configure Route53 DNS

---

## Branch Information

**Current Branch**: feature/critical-fixes-and-enhancements  
**Commits**: 3 (8b1695d, 9d6b261, e7c878e)  
**Files Changed**: 45 files  
**Lines Added**: ~8,000

**Key Changes**:
- Pod Security Standards
- AWS Secrets Manager integration
- HTTPS/TLS support (cert-manager + ACM)
- Configurable NLB
- Custom VPC support
- 45 automated tests
- 6 implementation blueprints

---

## Useful Links

- Issues: `.kiro/issues.md` (ISSUE-000 is current blocker)
- Progress: `.kiro/progress.md`
- Memory: `.kiro/memory.md`
- ECR Setup: `.kiro/ecr-setup.md`
- Blueprints: `blueprints/` directory
