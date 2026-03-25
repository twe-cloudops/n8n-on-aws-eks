# Final Deployment Summary - entapps-npe

**Date**: 2026-03-25  
**Status**: ✅ WORKING  
**URL**: https://n8n-cluster.001.ent-apps-npe-apse2.ent-apps-npe.twecloud.com/

---

## Critical Issue Resolved

**Problem**: NLB doesn't support TLS termination with HTTP backends  
**Solution**: Switched to ALB (Application Load Balancer)

---

## Final Architecture

```
User (10.0.0.0/8) 
    ↓ HTTPS:443
Internal ALB (sg-024ef8e10727c7fde)
    ↓ HTTP
Target Group (n8n-alb-tg)
    ↓ HTTP:32752
EKS Nodes (NodePort)
    ↓ HTTP:5678
n8n Pod
    ↓ PostgreSQL
RDS (n8n-postgres)
```

---

## Resources Created

### EKS Cluster
- **Name**: n8n-cluster
- **Nodes**: 2 x t3.medium
- **Kubernetes**: 1.34
- **VPC**: vpc-0b599ff538b98d5b6 (10.119.16.0/20)

### Application
- **Pod**: n8n (1/1 Running)
- **Image**: 993676232205.dkr.ecr.ap-southeast-2.amazonaws.com/twe-container-dockerhub/n8nio/n8n:2.11.0
- **Service**: NodePort 32752

### Database
- **Instance**: n8n-postgres
- **Engine**: PostgreSQL 16.6
- **Endpoint**: n8n-postgres.chfsch4a7joq.ap-southeast-2.rds.amazonaws.com

### Load Balancer (ALB)
- **Name**: n8n-alb
- **Type**: Application Load Balancer
- **Scheme**: Internal
- **DNS**: internal-n8n-alb-843756361.ap-southeast-2.elb.amazonaws.com
- **Listener**: HTTPS:443 → HTTP backend
- **Certificate**: arn:aws:acm:ap-southeast-2:777594735656:certificate/22f41fd9-9fbd-4d2c-ac8d-86f4518f48e2

### Security Groups
- **ALB SG**: sg-024ef8e10727c7fde
  - Inbound: 10.0.0.0/8:443 (corporate network)
  - Inbound: 10.119.16.0/20:443 (VPC)
  - Outbound: All traffic
- **Node SG**: sg-0057bb56678ce022b
  - Inbound: 10.119.16.0/20:32752 (from ALB)

### DNS
- **Domain**: n8n-cluster.001.ent-apps-npe-apse2.ent-apps-npe.twecloud.com
- **Type**: CNAME
- **Target**: internal-n8n-alb-843756361.ap-southeast-2.elb.amazonaws.com
- **Hosted Zone**: Z05190842L5HZFP29TEMH

---

## Key Learnings

### 1. NLB vs ALB for HTTPS
- **NLB**: Supports TLS termination but only forwards to TCP/TLS backends (not HTTP)
- **ALB**: Supports TLS termination with HTTP backends ✅
- **Use ALB** when you need HTTPS → HTTP

### 2. Security Group Planning
- **Always ask about network ranges** for internal load balancers
- Don't assume VPC CIDR only
- Corporate networks often use 10.0.0.0/8 or similar

### 3. Load Balancer Selection
- **ALB**: Layer 7, HTTP/HTTPS, path-based routing, TLS termination to HTTP
- **NLB**: Layer 4, TCP/UDP/TLS, high performance, TLS passthrough or termination to TCP/TLS only

---

## Issues Encountered and Fixed

### Issue 1: NLB TLS Listener
- **Problem**: NLB TLS listener terminates TLS but can only forward to TCP/TLS targets
- **Symptom**: "Empty reply from server"
- **Fix**: Switched to ALB

### Issue 2: Security Group
- **Problem**: ALB SG only allowed VPC CIDR (10.119.16.0/20)
- **Symptom**: Connection timeout from corporate network
- **Fix**: Added 10.0.0.0/8 to inbound rules

### Issue 3: Target Health
- **Problem**: Initial target registration delay
- **Symptom**: Targets showing "initial" state
- **Fix**: Wait 30-60 seconds for health checks

---

## Access Information

**URL**: https://n8n-cluster.001.ent-apps-npe-apse2.ent-apps-npe.twecloud.com/

**Requirements**:
- Connected to corporate network (10.0.0.0/8)
- Or connected to VPC via Direct Connect/VPN

**Test Command**:
```bash
curl -v https://n8n-cluster.001.ent-apps-npe-apse2.ent-apps-npe.twecloud.com/
```

---

## Next Steps

1. ✅ Access n8n and create owner account
2. ✅ Test workflow creation
3. ⏳ Update deployment scripts to use ALB by default
4. ⏳ Document ALB vs NLB decision in README
5. ⏳ Clean up unused NLB resources
6. ⏳ Commit and merge to main

---

## Cleanup Tasks

### Remove Unused NLB
```bash
export AWS_PROFILE=entapps-npe

# Delete NLB
aws elbv2 delete-load-balancer \
  --load-balancer-arn arn:aws:elasticloadbalancing:ap-southeast-2:777594735656:loadbalancer/net/n8n-nlb/d66008a772d333b5 \
  --region ap-southeast-2

# Delete target group (after NLB is deleted)
aws elbv2 delete-target-group \
  --target-group-arn arn:aws:elasticloadbalancing:ap-southeast-2:777594735656:targetgroup/n8n-tg-tcp/2434bc6c03d3fed0 \
  --region ap-southeast-2
```

---

**Status**: ✅ DEPLOYMENT COMPLETE AND WORKING  
**Last Updated**: 2026-03-25T15:20:00+11:00
