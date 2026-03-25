#!/bin/bash
set -euo pipefail

# Configure proxy on EKS nodes for internet access
# Run this after cluster creation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
PROXY_URL="${PROXY_URL:-http://10.122.108.59:8080}"
CLUSTER_NAME="${CLUSTER_NAME:-n8n-cluster}"
REGION="${REGION:-ap-southeast-2}"

print_header "Configuring Proxy on EKS Nodes"

info "Proxy URL: $PROXY_URL"
info "Cluster: $CLUSTER_NAME"
info "Region: $REGION"

# Get VPC CIDR for NO_PROXY
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" --query 'Vpcs[0].CidrBlock' --output text)

info "VPC CIDR: $VPC_CIDR"

# Create NO_PROXY list
NO_PROXY="localhost,127.0.0.1,169.254.169.254,.internal,.svc,.svc.cluster.local,$VPC_CIDR,.amazonaws.com"

info "NO_PROXY: $NO_PROXY"

# Get node instance IDs
NODE_INSTANCES=$(kubectl get nodes -o json | jq -r '.items[].spec.providerID' | cut -d'/' -f5)

info "Configuring proxy on nodes..."

for INSTANCE in $NODE_INSTANCES; do
    info "Configuring instance: $INSTANCE"
    
    # Create proxy configuration script
    PROXY_SCRIPT=$(cat << 'EOF'
#!/bin/bash
set -euo pipefail

PROXY_URL="__PROXY_URL__"
NO_PROXY="__NO_PROXY__"

echo "Configuring proxy on $(hostname)"

# Configure system-wide proxy
cat > /etc/profile.d/proxy.sh << PROXY_EOF
export HTTP_PROXY="$PROXY_URL"
export HTTPS_PROXY="$PROXY_URL"
export NO_PROXY="$NO_PROXY"
export http_proxy="$PROXY_URL"
export https_proxy="$PROXY_URL"
export no_proxy="$NO_PROXY"
PROXY_EOF

# Configure containerd proxy
mkdir -p /etc/systemd/system/containerd.service.d
cat > /etc/systemd/system/containerd.service.d/http-proxy.conf << CONTAINERD_EOF
[Service]
Environment="HTTP_PROXY=$PROXY_URL"
Environment="HTTPS_PROXY=$PROXY_URL"
Environment="NO_PROXY=$NO_PROXY"
CONTAINERD_EOF

# Configure dnf/yum proxy
if [ -f /etc/dnf/dnf.conf ]; then
    grep -q "^proxy=" /etc/dnf/dnf.conf || echo "proxy=$PROXY_URL" >> /etc/dnf/dnf.conf
fi

# Configure kubelet proxy
mkdir -p /etc/systemd/system/kubelet.service.d
cat > /etc/systemd/system/kubelet.service.d/http-proxy.conf << KUBELET_EOF
[Service]
Environment="HTTP_PROXY=$PROXY_URL"
Environment="HTTPS_PROXY=$PROXY_URL"
Environment="NO_PROXY=$NO_PROXY"
KUBELET_EOF

# Reload and restart services
systemctl daemon-reload
systemctl restart containerd
systemctl restart kubelet

echo "Proxy configuration complete"
EOF
)
    
    # Replace placeholders
    PROXY_SCRIPT="${PROXY_SCRIPT//__PROXY_URL__/$PROXY_URL}"
    PROXY_SCRIPT="${PROXY_SCRIPT//__NO_PROXY__/$NO_PROXY}"
    
    # Execute on node via SSM
    info "Executing proxy configuration via SSM..."
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids "$INSTANCE" \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=[\"$PROXY_SCRIPT\"]" \
        --region "$REGION" \
        --query 'Command.CommandId' \
        --output text)
    
    # Wait for command to complete
    sleep 5
    STATUS=$(aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE" \
        --region "$REGION" \
        --query 'Status' \
        --output text)
    
    if [ "$STATUS" = "Success" ]; then
        success "Instance $INSTANCE configured"
    else
        warning "Instance $INSTANCE configuration status: $STATUS"
    fi
done

print_header "Proxy Configuration Complete"

info "Verifying configuration..."
echo ""
info "Test proxy from a pod:"
echo "  kubectl run test-proxy --image=curlimages/curl:latest --rm -it --restart=Never -- curl -v https://www.google.com"
echo ""

success "All nodes configured with proxy settings"
