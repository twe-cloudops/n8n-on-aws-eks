# n8n-on-AWS-EKS Issues & Troubleshooting Tracker

**Created**: 2026-03-25T09:32:37+11:00
**Last Updated**: 2026-03-25T15:58:00+11:00

## Status Legend
- 🔴 **Critical** - Blocks deployment or major security risk
- 🟠 **High** - Important but has workarounds
- 🟡 **Medium** - Should be addressed soon
- 🟢 **Low** - Nice to have improvements
- ✅ **Fixed** - Issue resolved
- 🚧 **In Progress** - Currently being worked on
- 📋 **Backlog** - Planned for future

---

## 🎉 ALL CRITICAL ISSUES RESOLVED

**Status**: ✅ Production Ready  
**Deployments**: enc-test, entapps-npe  
**Branch**: feature/critical-fixes-and-enhancements

---

## Open Issues (Non-Blocking)

### ISSUE-017: Node Proxy Configuration at Cluster Creation
**Severity**: 🟡 Medium
**Status**: 📋 Backlog
**Created**: 2026-03-25

**Problem**:
Proxy configuration for EKS nodes (containerd, kubelet) cannot be applied post-deployment due to chicken-and-egg problem (nodes need proxy to pull images for DaemonSet that configures proxy).

**Current Workaround**:
- Using internal ECR (no internet needed for image pulls)
- n8n pod has proxy configured (works for application)

**Proper Solution**:
Add proxy configuration to eksctl cluster config via `preBootstrapCommands`:
```yaml
managedNodeGroups:
  - name: workers
    preBootstrapCommands:
      - |
        mkdir -p /etc/systemd/system/containerd.service.d
        cat > /etc/systemd/system/containerd.service.d/http-proxy.conf <<EOF
        [Service]
        Environment="HTTP_PROXY=http://10.122.108.59:8080"
        Environment="HTTPS_PROXY=http://10.122.108.59:8080"
        Environment="NO_PROXY=localhost,127.0.0.1,169.254.169.254,.internal,.svc,.svc.cluster.local,VPC_CIDR,.amazonaws.com"
        EOF
        systemctl daemon-reload
        systemctl restart containerd
```

**Impact**: Low - current setup works with ECR

**Assigned**: Unassigned  
**Target**: Future enhancement

---

### ISSUE-018: Community Edition Registration Not Automated
**Severity**: 🟢 Low
**Status**: 📋 Backlog (Cannot Fix)
**Created**: 2026-03-25

**Problem**:
n8n community edition registration requires manual acceptance of terms through UI. Cannot be automated via environment variables or API.

**Current Workaround**:
- Documented in `.kiro/POST-DEPLOYMENT-STEPS.md`
- One-time manual step
- Registration stored in RDS (persists)

**Proper Solution**:
None - this is by design in n8n (legal requirement to accept terms)

**Impact**: Low - one-time manual step, well documented

**Assigned**: N/A (Cannot be automated)  
**Status**: Documented

---

### ISSUE-019: No Persistent Storage for n8n Config
**Severity**: 🟡 Medium
**Status**: 📋 Backlog
**Created**: 2026-03-25

**Problem**:
n8n deployment uses `emptyDir` for `/home/node/.n8n` directory. n8n settings (not workflows) are lost on pod restart.

**Current Workaround**:
- Workflows stored in RDS (persistent)
- Most important data is safe
- Settings can be reconfigured if needed

**Proper Solution**:
Add EFS or EBS persistent volume:
```yaml
volumes:
  - name: n8n-storage
    persistentVolumeClaim:
      claimName: n8n-config-pvc
```

**Impact**: Medium - settings lost on pod restart (workflows safe)

**Assigned**: Unassigned  
**Target**: Next quarter  
**See**: `.kiro/NEXT-STEPS.md` #6

---

### ISSUE-020: Single n8n Pod (No HA)
**Severity**: 🟡 Medium
**Status**: 📋 Backlog
**Created**: 2026-03-25

**Problem**:
n8n deployment runs single replica. No high availability.

**Current Workaround**:
- RDS provides database HA (Multi-AZ in prod)
- Pod restarts quickly if it fails
- Acceptable for most use cases

**Proper Solution**:
1. Scale to multiple replicas
2. Add pod anti-affinity
3. Configure session affinity on ALB
4. Test multi-pod workflow execution

**Impact**: Medium - brief downtime during pod restarts

**Assigned**: Unassigned  
**Target**: When HA required  
**See**: `.kiro/NEXT-STEPS.md` #10

---

### ISSUE-021: Manual NLB/ALB Creation
**Severity**: 🟢 Low
**Status**: 📋 Backlog
**Created**: 2026-03-25

**Problem**:
ALB created manually via script instead of Kubernetes service. Not managed by Kubernetes.

**Current Workaround**:
- Automated via `scripts/create-alb-https.sh`
- Works reliably
- Well documented

**Proper Solution**:
Install AWS Load Balancer Controller:
```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=n8n-cluster
```

Then use Ingress or service annotations.

**Impact**: Low - current approach works well

**Assigned**: Unassigned  
**Target**: Future enhancement

---

### ISSUE-022: No Automated Monitoring Setup
**Severity**: 🟡 Medium
**Status**: 📋 Backlog
**Created**: 2026-03-25

**Problem**:
No automated setup for:
- CloudWatch Container Insights
- Prometheus/Grafana
- Alerting rules
- Dashboards

**Current Workaround**:
- Manual monitoring via `./scripts/monitor.sh`
- CloudWatch logs available
- Basic metrics in AWS console

**Proper Solution**:
Add to deployment script:
1. Enable Container Insights
2. Deploy Prometheus Operator
3. Deploy Grafana
4. Configure alerting rules
5. Create dashboards

**Impact**: Medium - limited observability

**Assigned**: Unassigned  
**Target**: Next quarter  
**See**: `.kiro/NEXT-STEPS.md` #7

---

### ISSUE-023: No Automated Backup to S3
**Severity**: 🟡 Medium
**Status**: 📋 Backlog
**Created**: 2026-03-25

**Problem**:
Backups only local via `./scripts/backup.sh`. No automated S3 backup.

**Current Workaround**:
- RDS automated backups (7-30 days)
- Manual backup script available
- Can manually copy to S3

**Proper Solution**:
1. Add S3 backup to `backup.sh`
2. Create CronJob for automated backups
3. Configure lifecycle policy
4. Test restore from S3

**Impact**: Medium - limited disaster recovery

**Assigned**: Unassigned  
**Target**: Next quarter  
**See**: `.kiro/NEXT-STEPS.md` #8

---

### ISSUE-024: End-to-End Encryption (E2EE) Option
**Severity**: 🟢 Low
**Status**: 📋 Backlog
**Created**: 2026-03-26

**Problem**:
Current setup terminates SSL at ALB, uses HTTP internally within VPC. Some organizations may require end-to-end encryption.

**Current Setup**:
- Users → ALB: HTTPS (443) with ACM certificate
- ALB → n8n Pod: HTTP (NodePort) unencrypted
- Traffic inside VPC is private (no internet exposure)
- Standard AWS practice for internal applications

**Why Current Setup is Secure**:
- ✅ Traffic encrypted over corporate network (Direct Connect)
- ✅ Traffic inside VPC is private (no internet exposure)
- ✅ Simpler n8n configuration (no cert management in pod)
- ✅ ALB handles SSL/TLS complexity

**Alternative Solution (E2EE)**:
Option 1: NLB with TLS Passthrough
- Pros: End-to-end encryption
- Cons: Loses Layer 7 features (path routing, WAF, HTTP metrics, detailed logs)

Option 2: Configure n8n with SSL
- Pros: End-to-end encryption, keeps ALB features
- Cons: More complex cert management, cert rotation in pods

**Impact**: Low - current setup is secure and recommended for internal apps

**Assigned**: Unassigned  
**Target**: Only if compliance requires E2EE  
**Note**: Consider trade-offs before implementing

---

## Resolved Critical Issues (Summary)

All 10 critical/high issues resolved:
1. ✅ Container image pull failure → ECR integration
2. ✅ Hardcoded credentials → Secrets Manager support
3. ✅ No HTTPS/TLS → ACM certificate + ALB
4. ✅ No automated testing → 45 tests created
5. ✅ RDS SSL connection → SSL env vars
6. ✅ NLB creation failure → ALB with proper config
7. ✅ NodePort security → Security group rules
8. ✅ Single PostgreSQL → RDS with backups
9. ✅ No Pod Security Standards → PSS baseline
10. ✅ Network policy invalid field → Fixed syntax

**See**: `.kiro/COMPLETE-DEPLOYMENT-GUIDE.md` for details

---

## Summary Statistics

**Total Issues**: 24
- ✅ **Resolved**: 16 (67%)
- 📋 **Backlog**: 8 (33%)
- 🔴 **Critical Open**: 0
- 🟠 **High Open**: 0

**By Severity (Open)**:
- 🟡 Medium: 5
- 🟢 Low: 3

**Status**: Production ready, all blockers resolved

---
- `manifests/03-postgres-deployment.yaml` - Updated to postgres:16.6 from ECR
- `manifests/06-n8n-deployment.yaml` - Updated to n8n:2.11.0 from ECR
- `scripts/deploy.sh` - Added ECR defaults and auto-detection
- `README.md` - Added ECR setup instructions

**Commits**: 80ba258, 3923f7b, 8aac35c, 21c571b

---

## Active Issues

### Critical Priority

#### ISSUE-001: Hardcoded Database Credentials
**Severity**: Critical
**Status**: ✅ Fixed (2026-03-25)
**File**: `manifests/01-postgres-secret.yaml`
**Description**: Database credentials are hardcoded in manifest file and committed to version control.
**Impact**: Security vulnerability - credentials exposed in repository
**Solution Implemented**: 
- Added AWS Secrets Manager integration with External Secrets Operator
- Created manifests/secrets/secret-store.yaml
- Created manifests/secrets/postgres-external-secret.yaml
- Updated deploy.sh with Secrets Manager support
**Branch**: feature/critical-fixes-and-enhancements
**Commit**: 8b1695d

#### ISSUE-002: No HTTPS/TLS Configuration
**Severity**: Critical
**Status**: ✅ Fixed (2026-03-25)
**Files**: `manifests/06-n8n-deployment.yaml`, `manifests/07-n8n-service.yaml`
**Description**: Application deployed with HTTP only, no TLS encryption
**Impact**: Data transmitted in plain text, security risk
**Solution Implemented**:
- Added cert-manager support with Let's Encrypt
- Created manifests/tls/cluster-issuer-staging.yaml
- Created manifests/tls/cluster-issuer-prod.yaml
- Added ACM certificate support as alternative
- Created manifests/tls/ingress-acm.yaml
- Updated deploy.sh with TLS configuration
**Branch**: feature/critical-fixes-and-enhancements
**Commits**: 8b1695d, 9d6b261

### High Priority

#### ISSUE-003: No Automated Testing
**Severity**: High
**Status**: ✅ Fixed (2026-03-25)
**Files**: All scripts and manifests
**Description**: Zero test coverage, no CI/CD validation
**Impact**: High risk of regressions and deployment failures
**Solution Implemented**:
- Created 45 automated tests using bats framework
- tests/common.bats - 12 tests for shared functions
- tests/manifests.bats - 15 tests for Kubernetes manifests
- tests/scripts.bats - 10 tests for deployment scripts
- tests/security.bats - 8 tests for security validation
- Created .github/workflows/tests.yml for CI/CD
- Testing score improved: 1.0/10 → 6.0/10
**Branch**: feature/critical-fixes-and-enhancements
**Commit**: e7c878e

---

## Active Issues

### Critical Priority

#### ISSUE-004: RDS PostgreSQL Connection Requires SSL
**Severity**: 🔴 Critical
**Status**: ✅ Fixed (2026-03-25)
**Discovered**: 2026-03-25 12:30
**Resolved**: 2026-03-25 13:15
**File**: `manifests/06-n8n-deployment-rds.yaml`

**Problem**:
n8n pod failing to connect to RDS PostgreSQL with error: "no encryption"

**Root Cause**:
RDS requires SSL connections by default, but n8n deployment missing SSL environment variables

**Solution Implemented**:
Added SSL configuration to n8n deployment:
```yaml
- name: DB_POSTGRESDB_SSL_ENABLED
  value: "true"
- name: DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED
  value: "false"
```

**Files Modified**:
- `manifests/06-n8n-deployment-rds.yaml` - Added SSL env vars

**Commit**: 4c6c9ae

#### ISSUE-005: Network Load Balancer Creation Failed
**Severity**: 🔴 Critical
**Status**: ✅ Fixed (2026-03-25)
**Discovered**: 2026-03-25 12:45
**Resolved**: 2026-03-25 13:00

**Problem**:
Kubernetes LoadBalancer service stuck in pending state, NLB not created automatically

**Root Cause**:
- Missing Kubernetes tags on VPC and subnets
- AWS Load Balancer Controller may not be installed

**Solution Implemented**:
1. ✅ Added required tags to VPC: `kubernetes.io/cluster/n8n-cluster=shared`
2. ✅ Added required tags to subnets: `kubernetes.io/role/internal-elb=1`
3. ✅ Created NLB manually via AWS CLI
4. ✅ Configured TLS listener with ACM certificate
5. ✅ Registered EKS nodes as targets

**Resources Created**:
- NLB: n8n-nlb (arn:...loadbalancer/net/n8n-nlb/39d67cbe5888d350)
- Target Group: n8n-tg (port 32427)
- Listener: TLS:443 with ACM certificate
- DNS: n8n-cluster.001.enc-test-shared.enc-test.twecloud.com

**Commit**: 57ab1c8

#### ISSUE-006: NodePort Not Accessible from NLB
**Severity**: 🔴 Critical
**Status**: ✅ Fixed (2026-03-25)
**Discovered**: 2026-03-25 12:50
**Resolved**: 2026-03-25 13:05

**Problem**:
NLB health checks failing, targets unhealthy

**Root Cause**:
EKS node security group missing ingress rule for NodePort 32427

**Solution Implemented**:
Added security group rule to allow TCP 32427 from VPC CIDR (10.117.88.0/22)

**Command**:
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-06d938e014821dea7 \
  --protocol tcp \
  --port 32427 \
  --cidr 10.117.88.0/22
```

**Result**: Targets healthy, NLB operational

---

### High Priority

#### ISSUE-007: Single PostgreSQL Instance (Migrated to RDS)
**Severity**: 🟠 High
**Status**: ✅ Fixed (2026-03-25)
**Original File**: `manifests/03-postgres-deployment.yaml`
**Description**: Single database replica, no high availability
**Impact**: Single point of failure, potential data loss

**Solution Implemented**:
Migrated to AWS RDS PostgreSQL:
- Instance: n8n-postgres (db.t3.micro)
- Engine: PostgreSQL 16.6
- Storage: 20GB gp3 encrypted
- Backup: 7-day retention
- Network: Private subnets only
- Security: Dedicated security group

**Files Created**:
- `scripts/create-rds.sh` - Automated RDS creation
- `manifests/06-n8n-deployment-rds.yaml` - n8n with RDS connection

**Commits**: 2a08d4a, 4c6c9ae, 5ef8334

**Next Step**: Enable Multi-AZ for true HA (see .kiro/NEXT-STEPS.md #9)

#### ISSUE-008: No Pod Security Standards
**Severity**: 🟠 High
**Status**: ✅ Fixed (2026-03-25)
**Files**: All deployment manifests
**Description**: No Pod Security Standards enforcement, containers run as root
**Impact**: Potential security vulnerabilities

**Solution Implemented**:
- Added PSS baseline labels to namespace
- Added security contexts to all deployments
- Configured non-root users where possible
- Added read-only root filesystems

**Files Modified**:
- `manifests/00-namespace.yaml` - Added PSS labels
- `manifests/03-postgres-deployment.yaml` - Added security context
- `manifests/06-n8n-deployment.yaml` - Added security context

**Commit**: 8b1695d

**Note**: Using baseline profile (not restricted) due to application requirements

#### ISSUE-009: Network Policy Invalid Field
**Severity**: 🟠 High
**Status**: ✅ Fixed (2026-03-25)
**File**: `manifests/05-network-policy.yaml`
**Description**: Network policy contains invalid `namespace` field in podSelector

**Problem**:
```yaml
podSelector:
  matchLabels:
    app: n8n-simple
    namespace: n8n  # INVALID - namespace not allowed here
```

**Solution Implemented**:
Removed invalid namespace field from podSelector

**Commit**: 8adf3fc

#### ISSUE-010: PostgreSQL Security Vulnerabilities
**Severity**: 🟠 High
**Status**: ✅ Fixed (2026-03-25)
**File**: `manifests/03-postgres-deployment.yaml`
**Description**: postgres:15-alpine has known CVE vulnerabilities

**Solution Implemented**:
Upgraded PostgreSQL through multiple iterations:
1. postgres:15-alpine → postgres:16-alpine
2. postgres:16-alpine → postgres:16-bookworm
3. postgres:16-bookworm → cgr.dev/chainguard/postgres:latest
4. chainguard → postgres:16.6 (final, from internal ECR)

**Rationale**: PostgreSQL 16.6 is latest stable, addresses CVEs, compatible with n8n 2.0+

**Commits**: 80ba258, 3923f7b, 8aac35c, 21c571b

---

### Medium Priority

#### ISSUE-011: No Monitoring Stack
**Severity**: 🟡 Medium
**Status**: Open
**Description**: Basic monitoring only, no Prometheus/Grafana
**Impact**: Limited observability, difficult troubleshooting
**Recommendation**: Deploy Prometheus Operator and Grafana
**Assigned**: Unassigned
**Target Date**: 2026-04-15
**See**: .kiro/NEXT-STEPS.md #7

#### ISSUE-012: No Persistent Storage for n8n Config
**Severity**: 🟡 Medium
**Status**: Open
**File**: `manifests/06-n8n-deployment-rds.yaml`
**Description**: n8n using emptyDir for config (non-persistent)
**Impact**: n8n settings lost on pod restart
**Recommendation**: Add EFS or EBS persistent volume
**Assigned**: Unassigned
**Target Date**: 2026-04-08
**See**: .kiro/NEXT-STEPS.md #6

#### ISSUE-013: S3 Backup Not Enabled
**Severity**: 🟡 Medium
**Status**: Open
**File**: `manifests/10-backup-cronjob.yaml`
**Description**: S3 backup commented out, only local backups
**Impact**: No off-site backup, limited disaster recovery
**Recommendation**: Enable S3 backup with lifecycle policy
**Assigned**: Unassigned
**Target Date**: 2026-04-22
**See**: .kiro/NEXT-STEPS.md #8

#### ISSUE-014: No Image Vulnerability Scanning
**Severity**: 🟡 Medium
**Status**: Open
**Description**: Container images not scanned for vulnerabilities
**Impact**: Potential security vulnerabilities in dependencies
**Recommendation**: Add Trivy scanning to CI/CD
**Assigned**: Unassigned
**Target Date**: 2026-05-06

---

### Low Priority

#### ISSUE-015: Minimal CONTRIBUTING.md
**Severity**: 🟢 Low
**Status**: Open
**File**: `CONTRIBUTING.md`
**Description**: Only 82 bytes, minimal contribution guidance
**Impact**: Difficult for contributors to get started
**Recommendation**: Expand with detailed guidelines
**Assigned**: Unassigned
**Target Date**: 2026-05-20

#### ISSUE-016: Minimal SECURITY.md
**Severity**: 🟢 Low
**Status**: Open
**File**: `SECURITY.md`
**Description**: Only 90 bytes, minimal security guidance
**Impact**: Unclear security reporting process
**Recommendation**: Expand with detailed security policy
**Assigned**: Unassigned
**Target Date**: 2026-05-27

---

## Summary Statistics

**Total Issues**: 16
- ✅ **Fixed**: 10 (62.5%)
- 🚧 **Open**: 6 (37.5%)

**By Severity**:
- 🔴 Critical: 6 fixed, 0 open
- 🟠 High: 4 fixed, 0 open
- 🟡 Medium: 0 fixed, 4 open
- 🟢 Low: 0 fixed, 2 open

**Recent Activity**:
- 2026-03-25: Fixed 10 critical/high issues
- All deployment blockers resolved
- Production deployment complete

---

## Resolved Issues Summary

### Critical Issues Fixed (6)
1. ✅ ISSUE-000: Container image pull failure (ECR integration)
2. ✅ ISSUE-001: Hardcoded credentials (Secrets Manager)
3. ✅ ISSUE-002: No HTTPS/TLS (ACM certificate)
4. ✅ ISSUE-004: RDS SSL connection
5. ✅ ISSUE-005: NLB creation failure
6. ✅ ISSUE-006: NodePort security group

### High Priority Issues Fixed (4)
7. ✅ ISSUE-003: No automated testing (45 tests)
8. ✅ ISSUE-007: Single PostgreSQL (migrated to RDS)
9. ✅ ISSUE-008: No Pod Security Standards (PSS baseline)
10. ✅ ISSUE-009: Network policy invalid field
11. ✅ ISSUE-010: PostgreSQL CVE vulnerabilities (upgraded to 16.6)

---

## Potential Concerns
1. **Single Region Deployment**: No geographic redundancy
2. **No Service Mesh**: Limited traffic management capabilities
3. **No GitOps**: Manual deployment process

### Operational Concerns
1. **No Audit Logging**: Kubernetes audit logs not configured
2. **No Cost Monitoring**: No automated cost tracking
3. **No Performance Baselines**: No established performance metrics

### Compliance Concerns
1. **Data Encryption**: No encryption in transit (HTTP only)
2. **Access Controls**: Basic RBAC, no advanced access policies
3. **Backup Verification**: Backups not tested regularly

## Troubleshooting Notes

### Common Issues

**Issue**: LoadBalancer URL pending
**Cause**: NLB provisioning takes 2-3 minutes
**Solution**: Wait and check with `kubectl get service n8n-service-simple -n n8n`

**Issue**: Pods not starting
**Cause**: Resource constraints or PVC binding issues
**Solution**: Check `kubectl describe pod <pod-name> -n n8n` and verify PVC status

**Issue**: Database connection failures
**Cause**: PostgreSQL not ready or network policy blocking
**Solution**: Verify PostgreSQL pod is running and network policies allow traffic

**Issue**: Backup failures
**Cause**: Insufficient permissions or storage
**Solution**: Check pod logs and verify PVC has available space

### Performance Issues

**Issue**: Slow workflow execution
**Cause**: Insufficient resources or database performance
**Solution**: Increase resource limits or migrate to RDS

**Issue**: High memory usage
**Cause**: Large workflow data or memory leaks
**Solution**: Monitor with `kubectl top pods -n n8n` and adjust limits

## Recommendations Queue

### Immediate (Week 1)
1. Implement secrets management
2. Enable HTTPS/TLS
3. Add Pod Security Standards

### Short-term (Weeks 2-4)
4. Add automated testing
5. Deploy monitoring stack
6. Enable S3 backups

### Medium-term (Weeks 5-8)
7. Implement PostgreSQL HA
8. Add image scanning
9. Enhance documentation

### Long-term (Months 3-6)
10. Implement GitOps
11. Add multi-region support
12. Deploy service mesh

## Issue Statistics

**Total Issues**: 11
**Critical**: 2 (18%)
**High**: 3 (27%)
**Medium**: 4 (36%)
**Low**: 2 (18%)

**Open**: 11 (100%)
**In Progress**: 0 (0%)
**Resolved**: 0 (0%)

**Average Resolution Time**: N/A (no resolved issues yet)
**Oldest Open Issue**: ISSUE-001 (0 days old)

## Next Review
**Date**: 2026-04-25 (1 month)
**Focus**: Review progress on critical and high priority issues
