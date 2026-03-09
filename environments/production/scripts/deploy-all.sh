#!/bin/bash
# =============================================================================
# Master Deployment Script — Viwell Production Frankfurt (eu-central-1)
# Orchestrates the full deployment after terraform apply
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
K8S_DIR="/Users/rao/work/misc/aws/k8s_v2_prod-main"
NAMESPACE="prod-viwell"

echo "============================================"
echo "  Viwell Production Deployment Orchestrator"
echo "============================================"
echo ""

# --- Phase 1: Connect to cluster and read Terraform outputs ---
echo "=== Phase 1: Connecting to EKS cluster ==="
cd "$SCRIPT_DIR/.."
KUBECONFIG_CMD=$(terraform output -raw eks_update_kubeconfig_command)
eval "$KUBECONFIG_CMD"
kubectl get nodes

# Read terraform outputs needed later
ACM_ARN=$(terraform output -raw acm_certificate_arn)
VELERO_ROLE_ARN=$(terraform output -raw velero_role_arn)
VELERO_BUCKET=$(terraform output -raw velero_bucket)
echo ""

# --- Phase 2: Create namespaces ---
echo "=== Phase 2: Creating namespaces ==="
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace elastic-prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace velero --dry-run=client -o yaml | kubectl apply -f -
echo ""

# --- Phase 3: Generate and apply ConfigMaps ---
echo "=== Phase 3: Generating ConfigMaps from Terraform outputs ==="
bash "$SCRIPT_DIR/generate-configmaps.sh"
echo "Applying ConfigMaps..."
kubectl apply -f "$SCRIPT_DIR/../generated-configmaps/postgres-config.yaml"
kubectl apply -f "$SCRIPT_DIR/../generated-configmaps/redis-config.yaml"
kubectl apply -f "$SCRIPT_DIR/../generated-configmaps/kafka-config.yaml"
kubectl apply -f "$SCRIPT_DIR/../generated-configmaps/elasticsearch-config.yaml"
kubectl apply -f "$SCRIPT_DIR/../generated-configmaps/s3-config.yaml"

# Apply sahha config from K8s manifests (external API, no terraform dependency)
if [ -f "$K8S_DIR/configmaps/sahha-cm.yaml" ]; then
  kubectl apply -f "$K8S_DIR/configmaps/sahha-cm.yaml" -n "$NAMESPACE"
fi
echo ""

# --- Phase 4: Apply secrets ---
echo "=== Phase 4: Applying secrets ==="
echo "NOTE: Secrets must be updated with correct values before applying!"
echo "Press Enter to continue or Ctrl+C to abort..."
read -r

for SECRET_FILE in \
  "$K8S_DIR/user/secret.yaml" \
  "$K8S_DIR/cli/secret.yaml" \
  "$K8S_DIR/notification/secret.yaml" \
  "$K8S_DIR/gamify/secret.yaml" \
  "$K8S_DIR/wearable/secret.yaml" \
  "$K8S_DIR/wearable-process/secret.yaml" \
  "$K8S_DIR/payment/secret.yaml" \
  "$K8S_DIR/cms/secret.yaml" \
  "$K8S_DIR/replication/secret.yaml" \
  "$K8S_DIR/replication/secrets-xoxo.yaml" \
  "$K8S_DIR/super-web-admin/secret.yaml"; do
  if [ -f "$SECRET_FILE" ]; then
    echo "  Applying: $SECRET_FILE"
    kubectl apply -f "$SECRET_FILE"
  else
    echo "  SKIP (not found): $SECRET_FILE"
  fi
done
echo ""

# --- Phase 5: Deploy services ---
echo "=== Phase 5: Deploying services ==="
for SVC_DIR in user cli notification gamify wearable wearable-process payment cms replication super-web-admin web-admin; do
  if [ -d "$K8S_DIR/$SVC_DIR" ]; then
    echo "  Deploying: $SVC_DIR"
    kubectl apply -f "$K8S_DIR/$SVC_DIR/" 2>/dev/null || true
  fi
done
echo ""

# --- Phase 6: Cron jobs ---
echo "=== Phase 6: Applying cron jobs ==="
if [ -d "$K8S_DIR/cli/jobs" ]; then
  kubectl apply -f "$K8S_DIR/cli/jobs/"
fi
for CRON in "$K8S_DIR/user"/cron-*.yaml; do
  [ -f "$CRON" ] && kubectl apply -f "$CRON"
done
if [ -f "$K8S_DIR/replication/cron-save-rewards.yaml" ]; then
  kubectl apply -f "$K8S_DIR/replication/cron-save-rewards.yaml"
fi
echo ""

# --- Phase 7: Elasticsearch ---
echo "=== Phase 7: Installing Elasticsearch ==="
helm repo add elastic https://helm.elastic.co 2>/dev/null || true
helm repo update
if [ -f "$K8S_DIR/elastic-search/values.yaml" ]; then
  # Inject ACM ARN from terraform into ES values
  ES_VALUES_TMP=$(mktemp)
  sed "s|PLACEHOLDER_ACM_ARN|${ACM_ARN}|g" "$K8S_DIR/elastic-search/values.yaml" > "$ES_VALUES_TMP"
  helm upgrade --install elasticsearch elastic/elasticsearch \
    -n elastic-prod \
    -f "$ES_VALUES_TMP" \
    --timeout 10m
  rm -f "$ES_VALUES_TMP"
fi
echo ""

# --- Phase 8: Lago billing ---
echo "=== Phase 8: Installing Lago ==="
echo "Creating lago secret first..."
bash "$SCRIPT_DIR/create-lago-secret.sh"
helm repo add lago https://getlago.github.io/lago-helm-charts/ 2>/dev/null || true
helm repo update
if [ -f "$K8S_DIR/../Additional-services/lago/lago-values.yaml" ]; then
  helm upgrade --install lago lago/lago \
    -n "$NAMESPACE" \
    -f "$K8S_DIR/../Additional-services/lago/lago-values.yaml" \
    --timeout 10m
fi
echo ""

# --- Phase 9: K8s Dashboard ---
echo "=== Phase 9: Installing Kubernetes Dashboard ==="
bash "$SCRIPT_DIR/install-dashboard.sh"
echo ""

# --- Phase 10: Ingress ---
echo "=== Phase 10: Applying Ingress ==="
bash "$SCRIPT_DIR/generate-ingress.sh"
kubectl apply -f "$SCRIPT_DIR/../generated-configmaps/ingress.yaml"
echo ""

# --- Phase 11: GitHub runner ---
echo "=== Phase 11: Deploying GitHub runner ==="
if [ -d "$K8S_DIR/../Additional-services/1-runners-github" ]; then
  kubectl apply -f "$K8S_DIR/../Additional-services/1-runners-github/"
fi
echo ""

# --- Phase 12: Velero backups ---
echo "=== Phase 12: Installing Velero for disaster recovery ==="
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts 2>/dev/null || true
helm repo update
helm upgrade --install velero vmware-tanzu/velero \
  -n velero \
  --set configuration.backupStorageLocation[0].name=default \
  --set configuration.backupStorageLocation[0].provider=aws \
  --set configuration.backupStorageLocation[0].bucket="${VELERO_BUCKET}" \
  --set configuration.backupStorageLocation[0].config.region=eu-central-1 \
  --set configuration.volumeSnapshotLocation[0].name=default \
  --set configuration.volumeSnapshotLocation[0].provider=aws \
  --set configuration.volumeSnapshotLocation[0].config.region=eu-central-1 \
  --set serviceAccount.server.annotations."eks\.amazonaws\.com/role-arn"="${VELERO_ROLE_ARN}" \
  --set initContainers[0].name=velero-plugin-for-aws \
  --set initContainers[0].image=velero/velero-plugin-for-aws:v1.9.0 \
  --set initContainers[0].volumeMounts[0].mountPath=/target \
  --set initContainers[0].volumeMounts[0].name=plugins \
  --set schedules.daily-backup.disabled=false \
  --set schedules.daily-backup.schedule="0 2 * * *" \
  --set schedules.daily-backup.template.ttl="168h" \
  --set schedules.daily-backup.template.includedNamespaces[0]="${NAMESPACE}" \
  --set credentials.useSecret=false \
  --timeout 5m
echo ""

# --- Verification ---
echo "============================================"
echo "  Deployment Complete! Verifying..."
echo "============================================"
echo ""
echo "=== Nodes ==="
kubectl get nodes -o wide
echo ""
echo "=== Pods ==="
kubectl get pods -n "$NAMESPACE"
echo ""
echo "=== Pods (elastic) ==="
kubectl get pods -n elastic-prod
echo ""
echo "=== Pods (velero) ==="
kubectl get pods -n velero
echo ""
echo "=== CronJobs ==="
kubectl get cronjobs -n "$NAMESPACE"
echo ""
echo "=== Ingress ==="
kubectl get ingress -n "$NAMESPACE"
kubectl get ingress -n kubernetes-dashboard
echo ""

echo "=== NEXT STEPS ==="
echo "1. Validate ACM cert: terraform output acm_dns_validation"
echo "2. Update Route53 DNS for viwell.tech -> new ALB"
echo "3. Test: curl -I https://user.viwell.tech"
echo "4. Update CI/CD templates for prod deployment"
echo "5. Update ELASTIC_PASSWORD in ES values.yaml (currently CHANGE_ME_BEFORE_DEPLOY)"
