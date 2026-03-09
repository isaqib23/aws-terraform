#!/bin/bash
# =============================================================================
# Create all required databases on the production RDS instance
# Run via bastion SSH tunnel:
#   ssh -L 5432:<rds_endpoint>:5432 ec2-user@<bastion_ip> -i ~/.ssh/viwell-prod/rds
#   Then run: ./create-databases.sh
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."
RDS_HOST=$(terraform output -raw rds_endpoint)
RDS_PORT=$(terraform output -raw rds_port)
RDS_USER="postgress_admin"

echo "=== Creating databases on $RDS_HOST ==="
echo "Make sure you have an SSH tunnel open to the bastion host"
echo ""

DATABASES=(
  "viwell_prod_central"
  "viwell_prod"
  "viwell_cms_prod"
  "viwell_lago"
  "viwell_wearable_prod"
  "viwell_prod_ci_central"
  "viwell_prod_ci_uae"
  "viwell_prod_ci_ksa"
)

for DB in "${DATABASES[@]}"; do
  echo "Creating database: $DB"
  PGPASSWORD="${RDS_PASS:-}" psql -h localhost -p 5432 -U "$RDS_USER" -d postgres -tc \
    "SELECT 1 FROM pg_database WHERE datname = '$DB'" | grep -q 1 \
    && echo "  -> already exists, skipping" \
    || PGPASSWORD="${RDS_PASS:-}" psql -h localhost -p 5432 -U "$RDS_USER" -d postgres -c "CREATE DATABASE $DB;" \
    && echo "  -> created"
done

echo ""
echo "=== All databases created ==="
echo "Verify: psql -h localhost -p 5432 -U $RDS_USER -c '\\l'"
