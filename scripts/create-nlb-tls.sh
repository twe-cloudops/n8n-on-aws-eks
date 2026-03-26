#!/bin/bash
set -euo pipefail

# Create NLB with TLS, ACM certificate, and Route53 DNS
# This script should be run after the EKS cluster and n8n are deployed

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-n8n-cluster}"
REGION="${REGION:-ap-southeast-2}"
NAMESPACE="${NAMESPACE:-n8n}"
SERVICE_NAME="${SERVICE_NAME:-n8n-service-simple}"

print_header "Creating NLB with TLS and DNS"

# Get configuration
info "Getting cluster configuration..."
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
SUBNETS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.subnetIds' --output text | tr '\t' ' ')
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" --query 'Vpcs[0].CidrBlock' --output text)

info "VPC: $VPC_ID ($VPC_CIDR)"
info "Subnets: $SUBNETS"

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

# Get NodePort and node information
info "Getting Kubernetes service information..."
NODE_PORT=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}')
NODE_INSTANCES=$(kubectl get nodes -o json | jq -r '.items[].spec.providerID' | cut -d'/' -f5)
NODE_SG=$(aws ec2 describe-instances --instance-ids $(echo $NODE_INSTANCES | awk '{print $1}') --region "$REGION" --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)

info "NodePort: $NODE_PORT"
info "Node Security Group: $NODE_SG"

# Add security group rule for NodePort
info "Adding security group rule for NodePort..."
aws ec2 authorize-security-group-ingress \
    --group-id "$NODE_SG" \
    --protocol tcp \
    --port "$NODE_PORT" \
    --cidr "$VPC_CIDR" \
    --region "$REGION" 2>/dev/null || warning "Security group rule may already exist"

success "Security group configured"

# Create NLB
info "Creating Network Load Balancer..."
NLB_ARN=$(aws elbv2 create-load-balancer \
    --name "${CLUSTER_NAME}-nlb" \
    --type network \
    --scheme internal \
    --subnets $SUBNETS \
    --region "$REGION" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

NLB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$NLB_ARN" \
    --region "$REGION" \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

success "NLB created: $NLB_DNS"

# Create target group
info "Creating target group..."
TG_ARN=$(aws elbv2 create-target-group \
    --name "${CLUSTER_NAME}-tg" \
    --protocol TCP \
    --port "$NODE_PORT" \
    --vpc-id "$VPC_ID" \
    --target-type instance \
    --health-check-protocol HTTP \
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

# Create TLS listener
info "Creating TLS listener on port 443..."
aws elbv2 create-listener \
    --load-balancer-arn "$NLB_ARN" \
    --protocol TLS \
    --port 443 \
    --certificates CertificateArn="$CERT_ARN" \
    --default-actions Type=forward,TargetGroupArn="$TG_ARN" \
    --region "$REGION" > /dev/null

success "TLS listener created"

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
                \"ResourceRecords\": [{\"Value\": \"$NLB_DNS\"}]
            }
        }]
    }" > /dev/null

success "DNS record created"

# Wait for targets to be healthy
info "Waiting for targets to become healthy..."
sleep 30

print_header "Deployment Complete"
echo ""
success "NLB ARN: $NLB_ARN"
success "Certificate ARN: $CERT_ARN"
success "Target Group ARN: $TG_ARN"
echo ""
success "Access URL: https://$DOMAIN"
echo ""
info "Checking target health..."
aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --region "$REGION" \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
    --output table
