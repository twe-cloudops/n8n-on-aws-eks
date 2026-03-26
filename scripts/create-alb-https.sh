#!/bin/bash
set -euo pipefail

# Create ALB with HTTPS for n8n
# Use this instead of create-nlb-tls.sh for proper HTTPS support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-n8n-cluster}"
REGION="${REGION:-ap-southeast-2}"
NAMESPACE="${NAMESPACE:-n8n}"
SERVICE_NAME="${SERVICE_NAME:-n8n-service-simple}"
CORPORATE_CIDR="${CORPORATE_CIDR:-10.0.0.0/8}"

print_header "Creating ALB with HTTPS for n8n"

# Get configuration
info "Getting cluster configuration..."
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
SUBNETS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.subnetIds' --output text | tr '\t' ' ')
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" --query 'Vpcs[0].CidrBlock' --output text)

info "VPC: $VPC_ID ($VPC_CIDR)"
info "Subnets: $SUBNETS"
info "Corporate CIDR: $CORPORATE_CIDR"

# Get domain from environment or prompt
if [ -z "${DOMAIN:-}" ]; then
    error "DOMAIN environment variable not set"
    info "Available hosted zones:"
    aws route53 list-hosted-zones --query 'HostedZones[*].[Name,Id]' --output table
    exit 1
fi

HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-}"
if [ -z "$HOSTED_ZONE_ID" ]; then
    error "HOSTED_ZONE_ID environment variable not set"
    exit 1
fi

info "Domain: $DOMAIN"
info "Hosted Zone: $HOSTED_ZONE_ID"

# Create ACM certificate
info "Creating ACM certificate..."
CERT_ARN=$(aws acm request-certificate \
    --domain-name "$DOMAIN" \
    --validation-method DNS \
    --region "$REGION" \
    --query 'CertificateArn' \
    --output text)

success "Certificate requested: $CERT_ARN"

# Wait for validation record
info "Waiting for validation record..."
sleep 10

VALIDATION_RECORD=$(aws acm describe-certificate \
    --certificate-arn "$CERT_ARN" \
    --region "$REGION" \
    --query 'Certificate.DomainValidationOptions[0].ResourceRecord' \
    --output json)

VALIDATION_NAME=$(echo "$VALIDATION_RECORD" | jq -r '.Name')
VALIDATION_VALUE=$(echo "$VALIDATION_RECORD" | jq -r '.Value')

info "Creating Route53 validation record..."
aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "{
        \"Changes\": [{
            \"Action\": \"CREATE\",
            \"ResourceRecordSet\": {
                \"Name\": \"$VALIDATION_NAME\",
                \"Type\": \"CNAME\",
                \"TTL\": 300,
                \"ResourceRecords\": [{\"Value\": \"$VALIDATION_VALUE\"}]
            }
        }]
    }" > /dev/null

success "Validation record created"

# Wait for certificate validation
info "Waiting for certificate validation (this may take 2-5 minutes)..."
for i in {1..30}; do
    STATUS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$REGION" --query 'Certificate.Status' --output text)
    if [ "$STATUS" = "ISSUED" ]; then
        success "Certificate validated!"
        break
    fi
    echo -n "."
    sleep 10
done
echo ""

# Create ALB security group
info "Creating ALB security group..."
ALB_SG=$(aws ec2 create-security-group \
    --group-name "${CLUSTER_NAME}-alb-sg" \
    --description "Security group for ${CLUSTER_NAME} ALB" \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --query 'GroupId' \
    --output text)

success "ALB Security Group: $ALB_SG"

# Add inbound rules
info "Adding inbound rules..."
aws ec2 authorize-security-group-ingress \
    --group-id "$ALB_SG" \
    --protocol tcp \
    --port 443 \
    --cidr "$VPC_CIDR" \
    --region "$REGION" > /dev/null

aws ec2 authorize-security-group-ingress \
    --group-id "$ALB_SG" \
    --protocol tcp \
    --port 443 \
    --cidr "$CORPORATE_CIDR" \
    --region "$REGION" > /dev/null

# Add outbound rule
aws ec2 authorize-security-group-egress \
    --group-id "$ALB_SG" \
    --protocol -1 \
    --cidr 0.0.0.0/0 \
    --region "$REGION" > /dev/null

success "Security group configured"

# Get NodePort and node information
info "Getting Kubernetes service information..."
NODE_PORT=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}')
NODE_INSTANCES=$(kubectl get nodes -o json | jq -r '.items[].spec.providerID' | cut -d'/' -f5)

info "NodePort: $NODE_PORT"

# Create ALB
info "Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name "${CLUSTER_NAME}-alb" \
    --type application \
    --scheme internal \
    --subnets $SUBNETS \
    --security-groups "$ALB_SG" \
    --region "$REGION" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --region "$REGION" \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

success "ALB created: $ALB_DNS"

# Create target group
info "Creating target group..."
TG_ARN=$(aws elbv2 create-target-group \
    --name "${CLUSTER_NAME}-alb-tg" \
    --protocol HTTP \
    --port "$NODE_PORT" \
    --vpc-id "$VPC_ID" \
    --target-type instance \
    --health-check-path /healthz \
    --region "$REGION" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

success "Target group created"

# Register targets
info "Registering node instances as targets..."
for INSTANCE in $NODE_INSTANCES; do
    aws elbv2 register-targets \
        --target-group-arn "$TG_ARN" \
        --targets Id="$INSTANCE" \
        --region "$REGION"
done

success "Targets registered"

# Create HTTPS listener
info "Creating HTTPS listener on port 443..."
aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTPS \
    --port 443 \
    --certificates CertificateArn="$CERT_ARN" \
    --default-actions Type=forward,TargetGroupArn="$TG_ARN" \
    --region "$REGION" > /dev/null

success "HTTPS listener created"

# Create Route53 DNS record
info "Creating Route53 DNS record..."
aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "{
        \"Changes\": [{
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"$DOMAIN\",
                \"Type\": \"CNAME\",
                \"TTL\": 300,
                \"ResourceRecords\": [{\"Value\": \"$ALB_DNS\"}]
            }
        }]
    }" > /dev/null

success "DNS record created"

# Wait for targets to be healthy
info "Waiting for targets to become healthy..."
sleep 30

print_header "Deployment Complete"
echo ""
success "ALB ARN: $ALB_ARN"
success "Certificate ARN: $CERT_ARN"
success "Target Group ARN: $TG_ARN"
success "Security Group: $ALB_SG"
echo ""
success "Access URL: https://$DOMAIN"
echo ""
info "Checking target health..."
aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --region "$REGION" \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
    --output table
