#!/bin/bash
# =============================================================================
# Generate production ingress YAML from Terraform outputs
# Auto-populates ACM ARN, subnet IDs, and all viwell.tech host rules
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Reading Terraform outputs ==="
ACM_ARN=$(terraform output -raw acm_certificate_arn)
SUBNETS=$(terraform output -json public_subnet_ids | jq -r 'join(",")')

OUTPUT_DIR="$(pwd)/generated-configmaps"
mkdir -p "$OUTPUT_DIR"

echo "ACM ARN: $ACM_ARN"
echo "Subnets: $SUBNETS"
echo ""

cat > "$OUTPUT_DIR/ingress.yaml" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: viwell-ingress
  namespace: prod-viwell
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: ${ACM_ARN}
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/actions.ssl-redirect: >
      {
        "Type": "redirect",
        "RedirectConfig": {
          "Protocol": "HTTPS",
          "Port": "443",
          "StatusCode": "HTTP_301"
        }
      }
    alb.ingress.kubernetes.io/group.name: prod-apps
    alb.ingress.kubernetes.io/subnets: ${SUBNETS}
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "30"
    external-dns.alpha.kubernetes.io/hostname: user.viwell.tech,notification.viwell.tech,wearable.viwell.tech,org.viwell.tech,admin.viwell.tech,cms.viwell.tech,gamify.viwell.tech
    external-dns.alpha.kubernetes.io/ttl: "60"
spec:
  ingressClassName: alb
  rules:
  - host: lago-api.viwell.tech
    http:
      paths:
      - backend:
          service:
            name: my-lago-release-api-svc
            port:
              number: 3000
        path: /
        pathType: Prefix
  - host: lago.viwell.tech
    http:
      paths:
      - backend:
          service:
            name: my-lago-release-front-svc
            port:
              number: 80
        path: /
        pathType: Prefix
  - host: user.viwell.tech
    http:
      paths:
      - path: /pay/docs
        pathType: Prefix
        backend:
          service:
            name: v2-service-payment-svc
            port:
              number: 3000
  - host: user.viwell.tech
    http:
      paths:
      - path: /pay
        pathType: Prefix
        backend:
          service:
            name: v2-service-payment-svc
            port:
              number: 3000
  - host: user.viwell.tech
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: viwell-user
            port:
              number: 3000
  - host: notification.viwell.tech
    http:
      paths:
      - backend:
          service:
            name: viwell-notification-prod
            port:
              number: 3000
        path: /
        pathType: Prefix
  - host: wearable.viwell.tech
    http:
      paths:
      - backend:
          service:
            name: viwell-wearable
            port:
              number: 3000
        path: /wearables
        pathType: Prefix
  - host: org.viwell.tech
    http:
      paths:
      - backend:
          service:
            name: viwell-admin-org-test
            port:
              number: 3000
        path: /
        pathType: Prefix
  - host: admin.viwell.tech
    http:
      paths:
      - backend:
          service:
            name: viwell-admin-test
            port:
              number: 3000
        path: /
        pathType: Prefix
  - host: cms.viwell.tech
    http:
      paths:
      - backend:
          service:
            name: viwell-cms-prod
            port:
              number: 1337
        path: /
        pathType: Prefix
  - host: gamify.viwell.tech
    http:
      paths:
      - backend:
          service:
            name: viwell-gamify
            port:
              number: 3000
        path: /
        pathType: Prefix
EOF

echo "=== Ingress generated: $OUTPUT_DIR/ingress.yaml ==="
echo "Apply with: kubectl apply -f $OUTPUT_DIR/ingress.yaml"
