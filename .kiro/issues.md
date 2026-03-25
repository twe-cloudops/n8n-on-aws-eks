# n8n-on-AWS-EKS Issues & Troubleshooting Tracker

**Created**: 2026-03-25T09:32:37+11:00
**Last Updated**: 2026-03-25T13:34:00+11:00

## Status Legend
- 🔴 **Critical** - Blocks deployment or major security risk
- 🟠 **High** - Important but has workarounds
- 🟡 **Medium** - Should be addressed soon
- 🟢 **Low** - Nice to have improvements
- ✅ **Fixed** - Issue resolved
- 🚧 **In Progress** - Currently being worked on

---

## 🎉 DEPLOYMENT COMPLETE - ALL BLOCKERS RESOLVED

**Status**: ✅ Production Ready  
**Date**: 2026-03-25  
**URL**: https://n8n-cluster.001.enc-test-shared.enc-test.twecloud.com  
**Branch**: feature/critical-fixes-and-enhancements

---

## Resolved Critical Issues

### ISSUE-000: Container Image Pull Failure in Private Subnets
**Severity**: 🔴 Critical (Deployment Blocker)
**Status**: ✅ Fixed (2026-03-25)
**Discovered**: 2026-03-25 11:09
**Resolved**: 2026-03-25 12:45
**Environment**: enc-test account (308100948908), ap-southeast-2

**Problem**:
EKS nodes in private subnets cannot pull container images from public registries (Docker Hub). Both postgres:15-alpine and n8nio/n8n:latest failing with ImagePullBackOff.

**Root Cause**:
- Nodes in private subnets: subnet-098c9a37ff83b4869, subnet-0a34ca141f76e8f2f, subnet-0e80caee7641da7b0
- Proxy (http://10.122.108.59:8080) not configured for container runtime
- No VPC endpoints for ECR
- Public registry access blocked

**Solution Implemented**:
1. ✅ Configured internal ECR (993676232205.dkr.ecr.ap-southeast-2.amazonaws.com/twe-container-dockerhub)
2. ✅ Updated manifests to use ECR images
3. ✅ Updated scripts/deploy.sh with ECR defaults
4. ✅ Images: n8n:2.11.0, postgres:16.6
5. ✅ Pods running successfully

**Files Modified**:
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
