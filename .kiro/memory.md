---
applyTo: '**'
---

# User Memory

## User Preferences
- Programming languages: Bash, YAML, Kubernetes manifests
- Code style preferences: Production-ready, enterprise-grade, comprehensive error handling
- Development environment: Linux (WSL), AWS CLI, kubectl, eksctl
- Communication style: Concise, direct, actionable

## Project Context
- Current project type: Infrastructure as Code - n8n on AWS EKS deployment
- Tech stack: Kubernetes, AWS EKS, PostgreSQL, n8n workflow automation
- Architecture patterns: Microservices, container orchestration, multi-region deployment
- Key requirements: Production-ready, cost-optimized, multi-region support, security

## Coding Patterns
- Comprehensive error handling with set -euo pipefail
- Shared functions library for consistency
- Color-coded output for better UX
- Help documentation for all scripts
- Secure credential handling via Kubernetes secrets

## Context7 Research History
- n8n deployment patterns
- AWS EKS best practices
- Kubernetes security policies

## Conversation History
- 2026-03-25 09:32: Initial repository review and tracking file creation
  - Completed comprehensive end-to-end analysis
  - Created 11 tracking and analysis files (132 KB documentation)
  - Identified 11 issues (2 critical, 3 high, 4 medium, 2 low)
  - Generated detailed statistics and metrics
  - Created actionable recommendations with timeline
  - Repository score: 7.0/10 (B grade)
  - Key findings: Excellent code quality, critical security gaps, missing tests

- 2026-03-25 09:52: Creating blueprints for critical fixes
  - Blueprint for secrets management (AWS Secrets Manager)
  - Blueprint for HTTPS/TLS (cert-manager + Let's Encrypt)
  - Blueprint for Pod Security Standards
  - Custom VPC/subnet selection
  - Configurable NLB (internal/external)

- 2026-03-25 09:58: Implementation in new branch
  - Created branch: feature/critical-fixes-and-enhancements
  - Implemented all critical security fixes
  - Added Pod Security Standards to manifests
  - Added AWS Secrets Manager integration
  - Added cert-manager and ACM support
  - Made NLB configurable (internal/external)
  - Added custom VPC configuration support
  - Commit: 8b1695d (29 files, +6,770 lines)

- 2026-03-25 10:43: Added ACM certificate support
  - Added ACM as alternative to cert-manager
  - Better for production (no rate limits, AWS managed)
  - Commit: 9d6b261

- 2026-03-25 10:44: Added comprehensive test suite
  - 45 automated tests using bats framework
  - Tests for common functions, manifests, scripts, security
  - GitHub Actions CI/CD integration
  - Testing score: 1.0/10 → 6.0/10
  - Commit: e7c878e

- 2026-03-25 10:48: Test deployment to enc-test account
  - Logged into AWS test account (308100948908)
  - Region: ap-southeast-2
  - VPC: vpc-0c6bc5a1488b5cfb0 (enc-test-shared-001)
  - Private subnets: subnet-098c9a37ff83b4869,subnet-0a34ca141f76e8f2f,subnet-0e80caee7641da7b0
  - Internal NLB configuration
  - Domain: n8n-cluster.001.enc-test-shared.enc-test.twecloud.com

- 2026-03-25 10:52: Installed kubectl and eksctl
  - Required proxy: http://10.122.108.59:8080
  - kubectl v1.35.3 installed
  - eksctl v0.224.0 installed

- 2026-03-25 10:55: EKS cluster creation
  - Cluster: n8n-cluster
  - Region: ap-southeast-2
  - VPC: vpc-0c6bc5a1488b5cfb0
  - 2 nodes (t3.medium) in private subnets
  - Kubernetes 1.34
  - Creation time: ~13 minutes
  - Status: ✅ Cluster created successfully

- 2026-03-25 11:09: Deployment issues encountered
  - EBS CSI driver can't pull images (proxy issue)
  - Pods can't pull container images from public registries
  - Private subnet + proxy environment blocking image pulls
  - Need: ECR with internal images OR VPC endpoints OR node proxy config

- 2026-03-25 11:18: Current status
  - Cluster running but pods failing to start
  - Issue: Nodes in private subnets can't pull images
  - Solution: Push images to internal ECR
  - Next: Configure deployments to use internal ECR images

## Notes
- Repository: n8n-on-aws-eks
- Version: 2.0 (Code Quality Release)
- Focus: End-to-end understanding and tracking infrastructure
