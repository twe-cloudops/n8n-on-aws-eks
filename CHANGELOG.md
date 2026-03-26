# Changelog

All notable changes to the n8n-on-aws-eks project will be documented in this file.

## [2.2.0] - 2026-03-26

### Added

#### Production-Ready Deployment
- **Environment-Based Deployment**: Dev, test, and prod configurations with cost optimization
- **EFS Persistent Storage**: Cost-optimized with Infrequent Access lifecycle policies
- **Secure Credentials**: Auto-generated passwords stored in AWS SSM/Secrets Manager
- **ALB with HTTPS**: Automated ALB creation with ACM certificates and Route53 DNS
- **RDS PostgreSQL**: Replaced containerized PostgreSQL with managed RDS
- **Proxy Support**: Corporate proxy integration for internet access
- **Configuration Management**: .env file for easy configuration across environments

#### New Scripts
- `deploy-full.sh`: Complete automated deployment with environment selection
- `create-alb-https.sh`: ALB + HTTPS + DNS automation
- `create-efs.sh`: EFS with cost-optimized lifecycle policies
- `create-rds.sh`: RDS PostgreSQL creation
- `create-owner-secret.sh`: Secrets Manager integration
- `create-owner-secret-ssm.sh`: SSM Parameter Store integration (recommended)
- `configure-proxy.sh`: Proxy configuration for nodes

#### Documentation
- Complete deployment guide with all fixes documented
- EFS implementation guide with cost optimization
- Owner credentials security documentation
- Post-deployment steps guide
- Architecture diagram (Draw.io format)
- 26 comprehensive documentation files

### Changed

#### Critical Fixes (10)
1. **LoadBalancer → NodePort + ALB**: Fixed Classic LB with public IPs issue
2. **NLB → ALB**: Switched to ALB for proper HTTPS → HTTP support
3. **Image Variables**: Fixed Kubernetes variable substitution
4. **Service Selector**: Fixed selector mismatch (app: n8n-simple → app: n8n)
5. **Security Group**: Added corporate network CIDR (10.0.0.0/8)
6. **RDS SSL**: Added SSL connection configuration
7. **n8n Registration**: Added proxy for community registration
8. **ECR Images**: Use internal ECR for private subnet deployments
9. **Network Policy**: Fixed invalid namespace field
10. **PostgreSQL**: Upgraded from 15-alpine to 16.6 for security

#### Standardization
- Renamed all deployments from "n8n-simple" to "n8n"
- Renamed service from "n8n-service-simple" to "n8n-service"
- Updated all scripts and documentation for consistent naming
- Removed stale manifests (postgres pod, old n8n deployment)
- Cleaned up unused manifest directories (secrets/, services/, tls/)

#### Configuration
- Made ECR account configurable via .env
- Made proxy URL configurable via .env
- Auto-detect AWS account for ECR if not specified
- Support for public Docker Hub images as fallback

### Fixed

#### Security
- Removed hardcoded passwords from repository
- Auto-generate random passwords during deployment
- Store credentials in AWS SSM/Secrets Manager
- Enable SSL for RDS connections
- Add Pod Security Standards to namespace

#### Deployment
- Fixed service selector to match deployment labels
- Fixed ALB security group for corporate network access
- Fixed image pulls in private subnets using ECR
- Fixed network policy syntax errors
- Updated tests to match current deployment structure

### Removed
- Deleted containerized PostgreSQL manifests (using RDS now)
- Removed unused External Secrets Operator manifests
- Removed unused cert-manager TLS manifests
- Removed account-specific infrastructure configs
- Archived 17 old documentation files

### Documentation
- Updated README with current architecture
- Added comprehensive deployment guide
- Documented all 10 critical fixes
- Added cost breakdown by environment
- Created architecture diagram
- Expanded CONTRIBUTING.md with proper guidelines
- Expanded SECURITY.md with security policy

### Cost Optimization
- Dev environment: ~$113/month (spot instances, minimal resources)
- Test environment: ~$200/month (standard instances, 7-day backups)
- Prod environment: ~$385/month (Multi-AZ, 30-day backups, auto-scaling)
- EFS Infrequent Access: 87.5% storage cost savings
- SSM Parameter Store: ~$5/year savings vs Secrets Manager

## [2.0.0] - 2024-12-01

### Added

#### Production-Ready Features
- **Persistent Storage**: Added PersistentVolumeClaims for PostgreSQL (20GB) and n8n (10GB) to prevent data loss
- **Storage Class**: Created gp3 storage class configuration for AWS EBS volumes
- **Network Policies**: Implemented Kubernetes NetworkPolicy for pod-to-pod communication security
- **Horizontal Pod Autoscaling**: Added HPA configuration for automatic scaling based on CPU (70%) and memory (80%)
- **Ingress Controller**: Added ALB Ingress configuration for HTTPS support and custom domains
- **Automated Backups**: Implemented CronJob for daily database backups at 2 AM UTC
- **Backup PVC**: Added 50GB PVC for backup storage with automated cleanup (keeps 7 days)
- **Restore Job**: Created Kubernetes Job for manual database restore operations

#### Enhanced Deployment Script
- Added AWS credentials validation before deployment
- Implemented better error handling and progress messages
- Added NAT gateway configuration for improved reliability
- Created gp3 storage class automatically if not exists
- Added comprehensive status reporting during deployment
- Implemented PVC waiting logic to ensure volumes are ready
- Improved timeout handling for deployments (600s for full initialization)
- Added EBS CSI driver installation with proper IAM role configuration

#### Improved Monitoring
- Enhanced monitor.sh with comprehensive status dashboard
- Added pod details, restarts, and resource usage tracking
- Included persistent volume status checks
- Added recent events display
- Improved error messages and validation
- Added quick command reference for common operations

#### Enhanced Cleanup Script
- Added confirmation prompt to prevent accidental deletion
- Implemented proper namespace deletion before cluster cleanup
- Added orphaned LoadBalancer cleanup
- Better error handling and status reporting
- Graceful handling of already-deleted resources

#### New Utility Scripts
- **backup.sh**: Manual database backup with timestamp
- **restore.sh**: Manual database restore with safety confirmation
- **get-logs.sh**: Quick log access for n8n and postgres pods

### Changed

#### Updated Deployments
- **PostgreSQL**: Updated to use PersistentVolumeClaim instead of emptyDir
- **Memory Resources**: Increased PostgreSQL memory from 512Mi to 1Gi limit
- **Health Probes**: Enhanced liveness and readiness probes with proper timeouts and failure thresholds
- **Storage**: Increased minimum disk size for EKS nodes to 50GB
- **Network**: Changed NAT gateway from Disable to Single for better reliability

#### Improved Security
- Network policies restrict pod communication to required ports only
- Egress policies allow necessary external connections (DNS, HTTPS)
- Added encryption for EBS volumes in EKS configuration

#### Better Resource Management
- Increased PostgreSQL memory to handle larger databases
- Improved health probe configuration to prevent false restarts
- Added proper timeouts for all probes (5-10 seconds)
- Set appropriate failure thresholds (3 attempts)

### Fixed
- Fixed deployment script profile handling (changed default from 'devops' to 'default')
- Fixed NAT gateway configuration for proper internet connectivity
- Improved EBS CSI driver installation with proper error handling
- Fixed PVC creation order in deployment script
- Added proper volume binding mode for StorageClass

### Documentation
- Updated project structure to reflect new files
- Added comprehensive deployment steps
- Included backup and restore procedures
- Documented new security features

## [1.0.0] - 2024-10-01

### Initial Release
- Basic EKS deployment with eksctl
- PostgreSQL 15 deployment with ClusterIP service
- n8n latest deployment with LoadBalancer service
- Basic namespace and resource quotas
- Initial deployment, monitoring, and cleanup scripts
- Network Load Balancer configuration

