# n8n-on-AWS-EKS Issues & Troubleshooting Tracker

**Created**: 2026-03-25T09:32:37+11:00
**Last Updated**: 2026-03-25T09:32:37+11:00

## Active Issues

### Critical Priority

#### ISSUE-001: Hardcoded Database Credentials
**Severity**: Critical
**Status**: Open
**File**: `manifests/01-postgres-secret.yaml`
**Description**: Database credentials are hardcoded in manifest file and committed to version control.
**Impact**: Security vulnerability - credentials exposed in repository
**Recommendation**: Implement AWS Secrets Manager or External Secrets Operator
**Assigned**: Unassigned
**Target Date**: 2026-04-01

#### ISSUE-002: No HTTPS/TLS Configuration
**Severity**: Critical
**Status**: Open
**Files**: `manifests/06-n8n-deployment.yaml`, `manifests/07-n8n-service.yaml`
**Description**: Application deployed with HTTP only, no TLS encryption
**Impact**: Data transmitted in plain text, security risk
**Recommendation**: Install cert-manager and configure Let's Encrypt
**Assigned**: Unassigned
**Target Date**: 2026-04-08

### High Priority

#### ISSUE-003: No Automated Testing
**Severity**: High
**Status**: Open
**Files**: All scripts and manifests
**Description**: Zero test coverage, no CI/CD validation
**Impact**: High risk of regressions and deployment failures
**Recommendation**: Implement unit tests, integration tests, and CI/CD validation
**Assigned**: Unassigned
**Target Date**: 2026-04-22

#### ISSUE-004: Single PostgreSQL Instance
**Severity**: High
**Status**: Open
**File**: `manifests/03-postgres-deployment.yaml`
**Description**: Single database replica, no high availability
**Impact**: Single point of failure, potential data loss
**Recommendation**: Implement StatefulSet with replication or migrate to AWS RDS
**Assigned**: Unassigned
**Target Date**: 2026-05-06

#### ISSUE-005: No Pod Security Standards
**Severity**: High
**Status**: Open
**Files**: All deployment manifests
**Description**: No Pod Security Standards enforcement, containers run as root
**Impact**: Potential security vulnerabilities
**Recommendation**: Add PSS labels and security contexts
**Assigned**: Unassigned
**Target Date**: 2026-04-29

### Medium Priority

#### ISSUE-006: No Monitoring Stack
**Severity**: Medium
**Status**: Open
**Description**: Basic monitoring only, no Prometheus/Grafana
**Impact**: Limited observability, difficult troubleshooting
**Recommendation**: Deploy Prometheus Operator and Grafana
**Assigned**: Unassigned
**Target Date**: 2026-05-20

#### ISSUE-007: S3 Backup Not Enabled
**Severity**: Medium
**Status**: Open
**File**: `manifests/10-backup-cronjob.yaml`
**Description**: S3 backup commented out, only local backups
**Impact**: No off-site backup, limited disaster recovery
**Recommendation**: Enable S3 backup with lifecycle policy
**Assigned**: Unassigned
**Target Date**: 2026-05-13

#### ISSUE-008: Minimal CI/CD Pipeline
**Severity**: Medium
**Status**: Open
**File**: `.github/workflows/ci.yml`
**Description**: Basic CI workflow with no validation
**Impact**: No automated quality checks
**Recommendation**: Add shellcheck, YAML linting, manifest validation
**Assigned**: Unassigned
**Target Date**: 2026-05-27

#### ISSUE-009: No Image Vulnerability Scanning
**Severity**: Medium
**Status**: Open
**Description**: Container images not scanned for vulnerabilities
**Impact**: Potential security vulnerabilities in dependencies
**Recommendation**: Add Trivy scanning to CI/CD
**Assigned**: Unassigned
**Target Date**: 2026-06-03

### Low Priority

#### ISSUE-010: Minimal CONTRIBUTING.md
**Severity**: Low
**Status**: Open
**File**: `CONTRIBUTING.md`
**Description**: Only 82 bytes, minimal contribution guidance
**Impact**: Difficult for contributors to get started
**Recommendation**: Expand with detailed guidelines
**Assigned**: Unassigned
**Target Date**: 2026-06-10

#### ISSUE-011: Minimal SECURITY.md
**Severity**: Low
**Status**: Open
**File**: `SECURITY.md`
**Description**: Only 90 bytes, minimal security guidance
**Impact**: Unclear security reporting process
**Recommendation**: Expand with detailed security policy
**Assigned**: Unassigned
**Target Date**: 2026-06-17

## Resolved Issues
None yet

## Potential Concerns

### Architecture Concerns
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
