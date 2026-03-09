#!/bin/bash
# =============================================================================
# Create the full lago-secrets K8s secret with ALL required keys
# Auto-generates crypto keys, reads RDS/Redis from Terraform outputs
# S3 uses IRSA (no access keys needed), SMTP is optional
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

RDS_HOST=$(terraform output -raw rds_endpoint)
REDIS_HOST=$(terraform output -raw redis_configuration_endpoint | cut -d: -f1)
RDS_PASSWORD="${RDS_PASS:-CHANGE_ME}"

NAMESPACE="prod-viwell"

echo "=== Creating lago-secrets in namespace $NAMESPACE ==="
echo "RDS: $RDS_HOST"
echo "Redis: $REDIS_HOST"
echo ""

# Auto-generate crypto keys (fresh install — no data to decrypt)
echo "Generating encryption keys..."
ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 32)
ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 32)
ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 32)
SECRET_KEY_BASE=$(openssl rand -hex 64)
RSA_PRIVATE_KEY=$(openssl genrsa 2048 2>/dev/null)

# S3 — use IRSA if possible, otherwise set these env vars before running:
#   export LAGO_S3_ACCESS_KEY_ID=AKIA...
#   export LAGO_S3_SECRET_ACCESS_KEY=...
S3_ACCESS_KEY="${LAGO_S3_ACCESS_KEY_ID:-none}"
S3_SECRET_KEY="${LAGO_S3_SECRET_ACCESS_KEY:-none}"

# SMTP — set these env vars before running if you need email:
#   export LAGO_SMTP_USERNAME=AKIA...
#   export LAGO_SMTP_PASSWORD=...
SMTP_USER="${LAGO_SMTP_USERNAME:-none}"
SMTP_PASS="${LAGO_SMTP_PASSWORD:-none}"

# Delete existing secret if any
kubectl delete secret lago-secrets -n "$NAMESPACE" --ignore-not-found

kubectl create secret generic lago-secrets -n "$NAMESPACE" \
  --from-literal=databaseUrl="postgresql://postgress_admin:${RDS_PASSWORD}@${RDS_HOST}:5432/viwell_lago" \
  --from-literal=redisUrl="redis://${REDIS_HOST}:6379" \
  --from-literal=redisCacheUrl="redis://${REDIS_HOST}:6379" \
  --from-literal=awsS3AccessKeyId="${S3_ACCESS_KEY}" \
  --from-literal=awsS3SecretAccessKey="${S3_SECRET_KEY}" \
  --from-literal=smtpUsername="${SMTP_USER}" \
  --from-literal=smtpPassword="${SMTP_PASS}" \
  --from-literal=encryptionDeterministicKey="${ENCRYPTION_DETERMINISTIC_KEY}" \
  --from-literal=encryptionKeyDerivationSalt="${ENCRYPTION_KEY_DERIVATION_SALT}" \
  --from-literal=encryptionPrimaryKey="${ENCRYPTION_PRIMARY_KEY}" \
  --from-literal=rsaPrivateKey="${RSA_PRIVATE_KEY}" \
  --from-literal=secretKeyBase="${SECRET_KEY_BASE}"

echo ""
echo "=== lago-secrets created ==="
echo ""
echo "Auto-generated keys:"
echo "  encryptionDeterministicKey:    ${ENCRYPTION_DETERMINISTIC_KEY}"
echo "  encryptionKeyDerivationSalt:   ${ENCRYPTION_KEY_DERIVATION_SALT}"
echo "  encryptionPrimaryKey:          ${ENCRYPTION_PRIMARY_KEY}"
echo "  secretKeyBase:                 ${SECRET_KEY_BASE:0:32}..."
echo ""
echo "SAVE THESE KEYS! If you lose them, Lago cannot decrypt its data."
echo ""
if [ "$S3_ACCESS_KEY" = "none" ]; then
  echo "WARNING: S3 keys not set. Set LAGO_S3_ACCESS_KEY_ID and LAGO_S3_SECRET_ACCESS_KEY env vars and re-run if needed."
fi
if [ "$SMTP_USER" = "none" ]; then
  echo "WARNING: SMTP not configured. Set LAGO_SMTP_USERNAME and LAGO_SMTP_PASSWORD env vars and re-run if needed."
fi
