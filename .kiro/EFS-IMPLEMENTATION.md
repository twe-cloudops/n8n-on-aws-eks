# EFS Persistent Storage Implementation

## Cost Optimization by Environment

### Dev/Test (Non-Prod)
- **Lifecycle Policy**: 7 days to Infrequent Access
- **Cost**: $3.60/month → $0.45/month after 7 days
- **Savings**: 87.5% cost reduction

### Production
- **Lifecycle Policy**: 30 days to Infrequent Access
- **Cost**: $3.60/month → $0.45/month after 30 days
- **Savings**: 87.5% cost reduction (delayed)

## Implementation Steps

### 1. Create EFS
```bash
# Dev/Test (aggressive cost savings)
ENVIRONMENT=dev ./scripts/create-efs.sh

# Production (standard lifecycle)
ENVIRONMENT=prod ./scripts/create-efs.sh
```

### 2. Install EFS CSI Driver
```bash
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.7"
```

### 3. Update StorageClass
Replace `${EFS_ID}` in `manifests/02-persistent-volumes.yaml` with actual EFS ID from script output.

### 4. Deploy
```bash
kubectl apply -f manifests/02-persistent-volumes.yaml
kubectl apply -f manifests/06-n8n-deployment-rds.yaml
```

## What's Stored in EFS

### Persistent (survives pod restarts):
- ✅ Custom nodes
- ✅ SSL certificates
- ✅ n8n configuration files
- ✅ Binary files
- ✅ Node modules

### Still in RDS:
- ✅ Workflows
- ✅ Credentials
- ✅ Execution history
- ✅ Settings

## Cost Comparison

| Storage | Current (emptyDir) | With EFS (10GB) |
|---------|-------------------|-----------------|
| Dev/Test | $0 | +$0.45/month (after 7 days) |
| Production | $0 | +$0.45/month (after 30 days) |

**Total Impact**: Negligible (~$5/year per environment)

## Benefits

1. **Config Persistence**: Settings survive pod restarts
2. **Custom Nodes**: Install and persist custom integrations
3. **HA Ready**: ReadWriteMany supports multiple pods
4. **Cost Optimized**: Infrequent Access reduces costs by 87.5%
5. **Encrypted**: Data encrypted at rest

## Rollback

To revert to emptyDir:
```bash
# Update deployment
kubectl patch deployment n8n -n n8n -p '{"spec":{"template":{"spec":{"volumes":[{"name":"n8n-storage","emptyDir":{}}]}}}}'

# Delete PVC
kubectl delete pvc n8n-pvc -n n8n
```
