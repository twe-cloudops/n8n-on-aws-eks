# Technical Debt Tracker

**Created**: 2026-03-25T09:32:37+11:00
**Repository**: n8n-on-aws-eks
**Version**: 2.0

---

## Overview

This document tracks technical debt items identified during repository analysis. Items are categorized by priority and impact.

---

## Critical Priority (Fix Immediately)

### 1. Hardcoded Database Credentials

**File**: `manifests/01-postgres-secret.yaml`
**Issue**: Database credentials hardcoded in manifest file
**Impact**: Security vulnerability, credentials exposed in version control
**Effort**: Medium (2-3 days)
**Risk**: High

**Current State**:
```yaml
stringData:
  POSTGRES_USER: n8nuser
  POSTGRES_PASSWORD: n8n-secure-password-2024
  POSTGRES_DB: n8n
```

**Recommended Solution**:
- Implement AWS Secrets Manager integration
- Use External Secrets Operator
- Update deployment scripts to create secrets dynamically
- Remove hardcoded values from repository

**Action Items**:
- [ ] Research External Secrets Operator
- [ ] Create AWS Secrets Manager setup script
- [ ] Update manifests to reference external secrets
- [ ] Update documentation
- [ ] Test deployment with new secrets management

**Assigned**: Unassigned
**Target Date**: 2026-04-01

---

### 2. No HTTPS/TLS Configuration

**Files**: `manifests/06-n8n-deployment.yaml`, `manifests/07-n8n-service.yaml`
**Issue**: HTTP-only deployment, no TLS encryption
**Impact**: Data transmitted in plain text, security risk
**Effort**: Low (1-2 days)
**Risk**: High

**Current State**:
- N8N_PROTOCOL: http
- N8N_SECURE_COOKIE: false
- No cert-manager integration

**Recommended Solution**:
- Install cert-manager
- Configure Let's Encrypt issuer
- Update ingress for TLS termination
- Enable secure cookies

**Action Items**:
- [ ] Add cert-manager to deployment
- [ ] Create ClusterIssuer manifest
- [ ] Update ingress with TLS configuration
- [ ] Update n8n environment variables
- [ ] Test HTTPS access
- [ ] Update documentation

**Assigned**: Unassigned
**Target Date**: 2026-04-08

---

## High Priority (Fix Soon)

### 3. No Automated Testing

**Files**: All scripts, manifests
**Issue**: Zero test coverage, no CI/CD validation
**Impact**: Risk of regressions, deployment failures
**Effort**: High (1-2 weeks)
**Risk**: Medium

**Current State**:
- No unit tests
- No integration tests
- No E2E tests
- Minimal CI workflow

**Recommended Solution**:
- Add shellcheck for bash scripts
- Add YAML validation
- Add Kubernetes manifest validation
- Create integration test suite
- Add E2E deployment tests

**Action Items**:
- [ ] Set up testing framework (bats for bash)
- [ ] Write unit tests for common.sh functions
- [ ] Add shellcheck to CI/CD
- [ ] Add YAML linting
- [ ] Create integration test suite
- [ ] Add E2E test for deployment
- [ ] Document testing procedures

**Assigned**: Unassigned
**Target Date**: 2026-04-22

---

### 4. Single PostgreSQL Instance (No HA)

**File**: `manifests/03-postgres-deployment.yaml`
**Issue**: Single replica, no high availability
**Impact**: Single point of failure, potential data loss
**Effort**: High (1-2 weeks)
**Risk**: Medium

**Current State**:
- replicas: 1
- No replication
- No failover mechanism

**Recommended Solution**:
- Implement PostgreSQL StatefulSet with replicas
- Add Patroni for HA management
- Configure streaming replication
- OR migrate to AWS RDS PostgreSQL

**Action Items**:
- [ ] Evaluate StatefulSet vs RDS
- [ ] Design HA architecture
- [ ] Create StatefulSet manifest
- [ ] Add replication configuration
- [ ] Test failover scenarios
- [ ] Update backup/restore scripts
- [ ] Document HA setup

**Assigned**: Unassigned
**Target Date**: 2026-05-06

---

### 5. No Pod Security Standards

**Files**: All deployment manifests
**Issue**: No Pod Security Standards enforcement
**Impact**: Potential security vulnerabilities
**Effort**: Medium (3-5 days)
**Risk**: Medium

**Current State**:
- No PSS labels on namespace
- No security contexts defined
- Containers run as root

**Recommended Solution**:
- Add PSS labels to namespace (restricted)
- Define security contexts for all pods
- Run containers as non-root
- Add read-only root filesystem where possible

**Action Items**:
- [ ] Add PSS labels to namespace
- [ ] Define security contexts
- [ ] Update container configurations
- [ ] Test with restricted PSS
- [ ] Document security requirements

**Assigned**: Unassigned
**Target Date**: 2026-04-29

---

## Medium Priority (Plan to Fix)

### 6. No Monitoring Stack

**Issue**: Basic monitoring only, no Prometheus/Grafana
**Impact**: Limited observability, difficult troubleshooting
**Effort**: Medium (1 week)
**Risk**: Low

**Recommended Solution**:
- Deploy Prometheus Operator
- Deploy Grafana
- Create custom dashboards
- Configure alerts

**Action Items**:
- [ ] Add Prometheus manifests
- [ ] Add Grafana manifests
- [ ] Create n8n dashboard
- [ ] Configure alerting rules
- [ ] Document monitoring setup

**Assigned**: Unassigned
**Target Date**: 2026-05-20

---

### 7. S3 Backup Not Enabled

**File**: `manifests/10-backup-cronjob.yaml`
**Issue**: S3 backup commented out, only local backups
**Impact**: No off-site backup, limited disaster recovery
**Effort**: Low (1 day)
**Risk**: Low

**Current State**:
```bash
# Optional: Upload to S3 (uncomment and configure)
# aws s3 cp ${BACKUP_FILE}.gz s3://${S3_BUCKET}/backups/
```

**Recommended Solution**:
- Enable S3 backup
- Add IAM role for S3 access
- Configure S3 bucket
- Add lifecycle policy

**Action Items**:
- [ ] Create S3 bucket
- [ ] Configure IAM role
- [ ] Enable S3 upload in CronJob
- [ ] Test S3 backup
- [ ] Document S3 configuration

**Assigned**: Unassigned
**Target Date**: 2026-05-13

---

### 8. Minimal CI/CD Pipeline

**File**: `.github/workflows/ci.yml`
**Issue**: Basic CI workflow, no validation
**Impact**: No automated quality checks
**Effort**: Medium (3-5 days)
**Risk**: Low

**Current State**:
```yaml
- run: echo "CI passed"
```

**Recommended Solution**:
- Add shellcheck
- Add YAML linting
- Add Kubernetes manifest validation
- Add security scanning
- Add dependency checking

**Action Items**:
- [ ] Add shellcheck workflow
- [ ] Add yamllint workflow
- [ ] Add kubeval/kubeconform
- [ ] Add trivy security scanning
- [ ] Add dependency updates (Dependabot)
- [ ] Document CI/CD pipeline

**Assigned**: Unassigned
**Target Date**: 2026-05-27

---

### 9. No Image Vulnerability Scanning

**Issue**: Container images not scanned for vulnerabilities
**Impact**: Potential security vulnerabilities in dependencies
**Effort**: Low (1-2 days)
**Risk**: Medium

**Recommended Solution**:
- Add Trivy scanning to CI/CD
- Scan images before deployment
- Set up vulnerability alerts
- Document remediation process

**Action Items**:
- [ ] Add Trivy to CI/CD
- [ ] Configure vulnerability thresholds
- [ ] Set up alerts
- [ ] Create remediation workflow
- [ ] Document scanning process

**Assigned**: Unassigned
**Target Date**: 2026-06-03

---

## Low Priority (Nice to Have)

### 10. Minimal CONTRIBUTING.md

**File**: `CONTRIBUTING.md`
**Issue**: Only 82 bytes, minimal guidance
**Impact**: Difficult for contributors to get started
**Effort**: Low (2-3 hours)
**Risk**: Very Low

**Current State**:
```markdown
# Contributing
1. Fork repository
2. Create feature branch
3. Submit Pull Request
```

**Recommended Solution**:
- Expand contribution guidelines
- Add code style guide
- Add commit message conventions
- Add PR template
- Add issue templates

**Action Items**:
- [ ] Write detailed contribution guide
- [ ] Add code style guidelines
- [ ] Create PR template
- [ ] Create issue templates
- [ ] Document development setup

**Assigned**: Unassigned
**Target Date**: 2026-06-10

---

### 11. Minimal SECURITY.md

**File**: `SECURITY.md`
**Issue**: Only 90 bytes, minimal security guidance
**Impact**: Unclear security reporting process
**Effort**: Low (2-3 hours)
**Risk**: Very Low

**Current State**:
```markdown
# Security Policy
Report security vulnerabilities privately via GitHub Security Advisory.
```

**Recommended Solution**:
- Expand security policy
- Add supported versions
- Add security best practices
- Add vulnerability disclosure timeline
- Add security contact information

**Action Items**:
- [ ] Write detailed security policy
- [ ] Document supported versions
- [ ] Add security best practices
- [ ] Define disclosure timeline
- [ ] Add security contacts

**Assigned**: Unassigned
**Target Date**: 2026-06-17

---

### 12. No GitOps Workflow

**Issue**: Manual deployment process, no GitOps
**Impact**: Less automation, potential for drift
**Effort**: High (2-3 weeks)
**Risk**: Very Low

**Recommended Solution**:
- Implement ArgoCD or Flux
- Restructure repository for GitOps
- Add automated sync
- Add drift detection

**Action Items**:
- [ ] Evaluate ArgoCD vs Flux
- [ ] Design GitOps structure
- [ ] Deploy GitOps tool
- [ ] Migrate manifests
- [ ] Configure automated sync
- [ ] Document GitOps workflow

**Assigned**: Unassigned
**Target Date**: 2026-07-15

---

### 13. No Vertical Pod Autoscaler

**Issue**: Only HPA, no VPA for resource optimization
**Impact**: Potential resource waste or starvation
**Effort**: Low (1 day)
**Risk**: Very Low

**Recommended Solution**:
- Deploy VPA
- Configure VPA for n8n and PostgreSQL
- Monitor recommendations
- Implement automated updates

**Action Items**:
- [ ] Deploy VPA
- [ ] Create VPA manifests
- [ ] Monitor recommendations
- [ ] Test automated updates
- [ ] Document VPA usage

**Assigned**: Unassigned
**Target Date**: 2026-06-24

---

### 14. No Service Mesh

**Issue**: No service mesh for advanced networking
**Impact**: Limited traffic management, no mTLS
**Effort**: High (2-3 weeks)
**Risk**: Very Low

**Recommended Solution**:
- Evaluate Istio vs Linkerd
- Deploy service mesh
- Configure mTLS
- Add traffic management

**Action Items**:
- [ ] Evaluate service mesh options
- [ ] Design mesh architecture
- [ ] Deploy service mesh
- [ ] Configure mTLS
- [ ] Add traffic policies
- [ ] Document mesh usage

**Assigned**: Unassigned
**Target Date**: 2026-08-01

---

## Deferred Items

### 15. Multi-Region Deployment

**Issue**: Single region deployment only
**Impact**: No geographic redundancy
**Effort**: Very High (1 month+)
**Risk**: Very Low

**Status**: Deferred to v3.0
**Reason**: Complex, requires significant architecture changes

---

### 16. Advanced Cost Optimization

**Issue**: Manual cost optimization only
**Impact**: Potential cost savings missed
**Effort**: High (2-3 weeks)
**Risk**: Very Low

**Status**: Deferred to v3.0
**Reason**: Requires monitoring data and usage patterns

---

## Technical Debt Summary

### By Priority

| Priority | Count | Total Effort | Avg Risk |
|----------|-------|--------------|----------|
| Critical | 2 | 3-5 days | High |
| High | 3 | 3-5 weeks | Medium |
| Medium | 4 | 2-3 weeks | Low |
| Low | 5 | 2-3 weeks | Very Low |
| Deferred | 2 | 2+ months | Very Low |
| **Total** | **16** | **3+ months** | **Medium** |

### By Category

| Category | Count | Priority |
|----------|-------|----------|
| Security | 5 | High |
| Testing | 2 | High |
| Monitoring | 2 | Medium |
| High Availability | 1 | High |
| Documentation | 2 | Low |
| Automation | 2 | Medium |
| Optimization | 2 | Low |

### Effort Distribution

```
Critical:  10% (3-5 days)
High:      40% (3-5 weeks)
Medium:    25% (2-3 weeks)
Low:       25% (2-3 weeks)
```

### Risk Distribution

```
High:      25% (4 items)
Medium:    31% (5 items)
Low:       31% (5 items)
Very Low:  13% (2 items)
```

---

## Recommended Roadmap

### Phase 1: Security (Weeks 1-3)
- Fix hardcoded credentials
- Enable HTTPS/TLS
- Add Pod Security Standards

### Phase 2: Testing (Weeks 4-6)
- Add unit tests
- Add integration tests
- Enhance CI/CD pipeline

### Phase 3: Reliability (Weeks 7-10)
- Implement PostgreSQL HA
- Enable S3 backups
- Add monitoring stack

### Phase 4: Optimization (Weeks 11-14)
- Add image scanning
- Implement VPA
- Enhance documentation

### Phase 5: Advanced (Weeks 15+)
- Implement GitOps
- Add service mesh
- Multi-region support

---

## Tracking Metrics

**Total Items**: 16
**Completed**: 0
**In Progress**: 0
**Blocked**: 0
**Deferred**: 2

**Completion Rate**: 0%
**Target Completion**: 2026-08-01 (4 months)

---

**Last Updated**: 2026-03-25T09:32:37+11:00
**Next Review**: 2026-04-25 (1 month)
