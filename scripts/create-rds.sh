#!/bin/bash
# Create RDS PostgreSQL instance for n8n
# Usage: ./create-rds.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-n8n-cluster}"
REGION="${REGION:-ap-southeast-2}"
AWS_PROFILE="${AWS_PROFILE:-test}"
VPC_ID="${VPC_ID:-vpc-0c6bc5a1488b5cfb0}"
PRIVATE_SUBNETS="${PRIVATE_SUBNETS:-subnet-098c9a37ff83b4869,subnet-0a34ca141f76e8f2f,subnet-0e80caee7641da7b0}"

# RDS Configuration
DB_INSTANCE_ID="${DB_INSTANCE_ID:-n8n-postgres}"
DB_NAME="${DB_NAME:-n8n}"
DB_USERNAME="${DB_USERNAME:-n8nuser}"
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)}"
DB_INSTANCE_CLASS="${DB_INSTANCE_CLASS:-db.t3.micro}"  # Free tier eligible
DB_ALLOCATED_STORAGE="${DB_ALLOCATED_STORAGE:-20}"     # Free tier: 20GB
DB_ENGINE_VERSION="${DB_ENGINE_VERSION:-16.6}"

print_header "🗄️ Creating RDS PostgreSQL for n8n"

log_info "Configuration:"
echo "   DB Instance: $DB_INSTANCE_ID"
echo "   DB Name: $DB_NAME"
echo "   DB Username: $DB_USERNAME"
echo "   Instance Class: $DB_INSTANCE_CLASS"
echo "   Storage: ${DB_ALLOCATED_STORAGE}GB"
echo "   Engine: PostgreSQL $DB_ENGINE_VERSION"
echo "   Region: $REGION"
echo "   VPC: $VPC_ID"
echo ""

# Check prerequisites
log_info "Checking prerequisites..."
check_prerequisites aws || error_exit "AWS CLI not found"
validate_aws_credentials "$AWS_PROFILE" || error_exit "AWS credentials validation failed"
log_success "Prerequisites validated"

# Get VPC CIDR for security group
log_info "Getting VPC CIDR..."
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" --profile "$AWS_PROFILE" \
    --query 'Vpcs[0].CidrBlock' --output text)
log_info "VPC CIDR: $VPC_CIDR"

# Create DB subnet group
log_info "Creating DB subnet group..."
SUBNET_GROUP_NAME="${DB_INSTANCE_ID}-subnet-group"

aws rds create-db-subnet-group \
    --db-subnet-group-name "$SUBNET_GROUP_NAME" \
    --db-subnet-group-description "Subnet group for $DB_INSTANCE_ID" \
    --subnet-ids $(echo $PRIVATE_SUBNETS | tr ',' ' ') \
    --region "$REGION" \
    --profile "$AWS_PROFILE" 2>/dev/null || log_info "Subnet group already exists"

log_success "DB subnet group ready"

# Create security group
log_info "Creating security group..."
SG_NAME="${DB_INSTANCE_ID}-sg"

SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "Security group for $DB_INSTANCE_ID" \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --query 'GroupId' \
    --output text 2>/dev/null) || {
    # Get existing SG
    SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'SecurityGroups[0].GroupId' \
        --output text)
    log_info "Using existing security group: $SG_ID"
}

# Add ingress rule for PostgreSQL from VPC
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 5432 \
    --cidr "$VPC_CIDR" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" 2>/dev/null || log_info "Ingress rule already exists"

log_success "Security group configured: $SG_ID"

# Create RDS instance
log_info "Creating RDS PostgreSQL instance..."
log_warning "This will take 5-10 minutes..."

aws rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --db-instance-class "$DB_INSTANCE_CLASS" \
    --engine postgres \
    --engine-version "$DB_ENGINE_VERSION" \
    --master-username "$DB_USERNAME" \
    --master-user-password "$DB_PASSWORD" \
    --allocated-storage "$DB_ALLOCATED_STORAGE" \
    --db-name "$DB_NAME" \
    --vpc-security-group-ids "$SG_ID" \
    --db-subnet-group-name "$SUBNET_GROUP_NAME" \
    --no-publicly-accessible \
    --backup-retention-period 7 \
    --preferred-backup-window "03:00-04:00" \
    --preferred-maintenance-window "mon:04:00-mon:05:00" \
    --storage-encrypted \
    --storage-type gp3 \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --tags "Key=Name,Value=$DB_INSTANCE_ID" "Key=Environment,Value=n8n" || {
    log_warning "RDS instance may already exist"
}

# Wait for RDS to be available
log_info "Waiting for RDS instance to be available..."
aws rds wait db-instance-available \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --region "$REGION" \
    --profile "$AWS_PROFILE"

# Get RDS endpoint
DB_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

log_success "RDS PostgreSQL instance created!"

echo ""
print_header "📋 RDS Connection Details"
echo ""
echo "Endpoint: $DB_ENDPOINT"
echo "Port: 5432"
echo "Database: $DB_NAME"
echo "Username: $DB_USERNAME"
echo "Password: $DB_PASSWORD"
echo ""
log_warning "Save these credentials securely!"
echo ""

# Create Kubernetes secret
log_info "Creating Kubernetes secret..."
kubectl create secret generic n8n-postgres-rds \
    --from-literal=host="$DB_ENDPOINT" \
    --from-literal=port="5432" \
    --from-literal=database="$DB_NAME" \
    --from-literal=username="$DB_USERNAME" \
    --from-literal=password="$DB_PASSWORD" \
    --namespace n8n \
    --dry-run=client -o yaml | kubectl apply -f -

log_success "Kubernetes secret created: n8n-postgres-rds"

echo ""
print_header "✅ RDS Setup Complete"
echo ""
echo "Next steps:"
echo "1. Update n8n deployment to use RDS"
echo "2. Remove PostgreSQL container deployment"
echo "3. Deploy n8n with RDS connection"
echo ""
echo "Connection string for n8n:"
echo "postgresql://$DB_USERNAME:$DB_PASSWORD@$DB_ENDPOINT:5432/$DB_NAME"
echo ""
