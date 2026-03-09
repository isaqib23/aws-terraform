#!/bin/bash
# =============================================================================
# Install K8s Dashboard v2.7.0
# Lesson from staging: Must install in kubernetes-dashboard namespace (hardcoded)
# Uses raw manifest since helm repo is deprecated
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

ACM_ARN=$(terraform output -raw acm_certificate_arn)
SUBNETS=$(terraform output -json public_subnet_ids | jq -r 'join(",")')

echo "=== Installing Kubernetes Dashboard v2.7.0 ==="

# Step 1: Install dashboard in its own namespace
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

echo "Waiting for dashboard pods..."
kubectl rollout status deployment/kubernetes-dashboard -n kubernetes-dashboard --timeout=120s

# Step 2: Create admin user with cluster-admin
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Step 3: Create ingress in kubernetes-dashboard namespace with shared ALB
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: ${ACM_ARN}
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/group.name: prod-apps
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/backend-protocol: HTTPS
    alb.ingress.kubernetes.io/subnets: ${SUBNETS}
spec:
  ingressClassName: alb
  rules:
  - host: dashboard.viwell.tech
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kubernetes-dashboard
            port:
              number: 443
EOF

echo ""
echo "=== Dashboard installed ==="
echo "Get login token: kubectl -n kubernetes-dashboard create token admin-user"
echo "Access: https://dashboard.viwell.tech"
