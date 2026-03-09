#!/bin/bash
# =============================================================================
# Create the full lago-secrets K8s secret with ALL required keys
# This prevents the staging issue where helm install timed out because
# the migration job couldn't find databaseUrl, redisUrl, etc.
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

RDS_HOST=$(terraform output -raw rds_endpoint)
REDIS_HOST=$(terraform output -raw redis_primary_endpoint | cut -d: -f1)

NAMESPACE="prod-viwell"

echo "=== Creating lago-secrets in namespace $NAMESPACE ==="
echo "RDS: $RDS_HOST"
echo "Redis: $REDIS_HOST"
echo ""
echo "IMPORTANT: Update the placeholder values below before running!"
echo ""

# Delete existing secret if any
kubectl delete secret lago-secrets -n "$NAMESPACE" --ignore-not-found

kubectl create secret generic lago-secrets -n "$NAMESPACE" \
  --from-literal=databaseUrl="postgresql://postgress_admin:CHANGE_ME@${RDS_HOST}:5432/viwell_lago" \
  --from-literal=redisUrl="redis://${REDIS_HOST}:6379" \
  --from-literal=redisCacheUrl="redis://${REDIS_HOST}:6379" \
  --from-literal=awsS3AccessKeyId="CHANGE_ME" \
  --from-literal=awsS3SecretAccessKey="CHANGE_ME" \
  --from-literal=smtpUsername="CHANGE_ME" \
  --from-literal=smtpPassword="CHANGE_ME" \
  --from-literal=encryptionDeterministicKey="CHANGE_ME" \
  --from-literal=encryptionKeyDerivationSalt="CHANGE_ME" \
  --from-literal=encryptionPrimaryKey="CHANGE_ME" \
  --from-literal=rsaPrivateKey="CHANGE_ME" \
  --from-literal=secretKeyBase="CHANGE_ME"

echo ""
echo "=== lago-secrets created ==="
echo "Now run: helm install lago lago/lago -n $NAMESPACE -f lago-values.yaml"
