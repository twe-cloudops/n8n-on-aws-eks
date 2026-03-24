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

## Notes
- Repository: n8n-on-aws-eks
- Version: 2.0 (Code Quality Release)
- Focus: End-to-end understanding and tracking infrastructure
