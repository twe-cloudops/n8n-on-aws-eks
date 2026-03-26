#!/bin/bash
set -euo pipefail

# Configure proxy on EKS nodes - simplified approach
# Uses a DaemonSet to configure all nodes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
PROXY_URL="${PROXY_URL:-http://10.122.108.59:8080}"
CLUSTER_NAME="${CLUSTER_NAME:-n8n-cluster}"
REGION="${REGION:-ap-southeast-2}"

print_header "Configuring Proxy on EKS Nodes"

info "Proxy URL: $PROXY_URL"

# Get VPC CIDR for NO_PROXY
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" --query 'Vpcs[0].CidrBlock' --output text)

NO_PROXY="localhost,127.0.0.1,169.254.169.254,.internal,.svc,.svc.cluster.local,$VPC_CIDR,.amazonaws.com"

info "VPC CIDR: $VPC_CIDR"
info "NO_PROXY: $NO_PROXY"

# Create DaemonSet to configure proxy
info "Creating proxy configuration DaemonSet..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: proxy-configurator
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: proxy-configurator
  template:
    metadata:
      labels:
        app: proxy-configurator
    spec:
      hostPID: true
      hostNetwork: true
      initContainers:
      - name: configure-proxy
        image: amazonlinux:2023
        command:
        - /bin/bash
        - -c
        - |
          set -euo pipefail
          
          echo "Configuring proxy on \$(hostname)"
          
          # Configure containerd proxy
          mkdir -p /host/etc/systemd/system/containerd.service.d
          cat > /host/etc/systemd/system/containerd.service.d/http-proxy.conf <<PROXY_EOF
          [Service]
          Environment="HTTP_PROXY=${PROXY_URL}"
          Environment="HTTPS_PROXY=${PROXY_URL}"
          Environment="NO_PROXY=${NO_PROXY}"
          PROXY_EOF
          
          # Configure kubelet proxy
          mkdir -p /host/etc/systemd/system/kubelet.service.d
          cat > /host/etc/systemd/system/kubelet.service.d/http-proxy.conf <<PROXY_EOF
          [Service]
          Environment="HTTP_PROXY=${PROXY_URL}"
          Environment="HTTPS_PROXY=${PROXY_URL}"
          Environment="NO_PROXY=${NO_PROXY}"
          PROXY_EOF
          
          # Reload systemd
          nsenter -t 1 -m -u -i -n systemctl daemon-reload
          nsenter -t 1 -m -u -i -n systemctl restart containerd || true
          nsenter -t 1 -m -u -i -n systemctl restart kubelet || true
          
          echo "Proxy configuration complete"
          
          # Keep container running
          sleep infinity
        securityContext:
          privileged: true
        volumeMounts:
        - name: host
          mountPath: /host
      containers:
      - name: pause
        image: gcr.io/google_containers/pause:3.2
      volumes:
      - name: host
        hostPath:
          path: /
EOF

success "DaemonSet created"

info "Waiting for DaemonSet to configure all nodes (30 seconds)..."
sleep 30

info "Checking DaemonSet status..."
kubectl get ds proxy-configurator -n kube-system

print_header "Proxy Configuration Complete"

success "All nodes are being configured with proxy settings"
echo ""
info "To remove the DaemonSet after configuration:"
echo "  kubectl delete ds proxy-configurator -n kube-system"
