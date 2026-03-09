#!/bin/bash
# =============================================================================
# Patch K8s secret files: replace old UAE RDS endpoint with new Frankfurt RDS
# Also updates aws_region from me-central-1 to eu-central-1
# Run BEFORE deploy-all.sh (or it runs automatically in Phase 4)
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

K8S_DIR="/Users/rao/work/misc/aws/k8s_v2_prod-main"

# Read new RDS endpoint from Terraform
NEW_RDS_HOST=$(terraform output -raw rds_endpoint)
NEW_RDS_PASSWORD="${RDS_PASS:-CHANGE_ME}"

# Old UAE RDS endpoint (base64 encoded in secrets)
OLD_RDS_HOST="rds-viwell-v2-master-prod.c7mu0u2aezg4.me-central-1.rds.amazonaws.com"
OLD_RDS_PASSWORD="bRs74Dr31fSd"
OLD_CMS_RDS_HOST="rds-viwell-v2.cjiqyeg0e6dk.me-central-1.rds.amazonaws.com"
OLD_CMS_RDS_PASSWORD="aRs743sfSd"

echo "=== Patching K8s secrets with Frankfurt RDS endpoint ==="
echo "Old RDS: $OLD_RDS_HOST"
echo "New RDS: $NEW_RDS_HOST"
echo ""

# Function: re-encode a base64 value after replacing old host/password
patch_secret_file() {
  local file="$1"
  local tmpfile=$(mktemp)

  echo "Patching: $file"

  while IFS= read -r line; do
    # Skip comments and non-data lines
    if echo "$line" | grep -qE '^\s+\S+:' && ! echo "$line" | grep -qE '^\s*#' && ! echo "$line" | grep -qE '(metadata|name|namespace|kind|apiVersion|data|type):'; then
      key=$(echo "$line" | sed 's/^\s*//' | cut -d: -f1)
      val=$(echo "$line" | sed 's/^[^:]*:\s*//' | tr -d ' "')

      # Try to decode
      decoded=$(echo "$val" | base64 -d 2>/dev/null) || decoded=""

      if [ -n "$decoded" ]; then
        changed=false

        # Replace old RDS host with new
        if echo "$decoded" | grep -q "$OLD_RDS_HOST"; then
          decoded=$(echo "$decoded" | sed "s|$OLD_RDS_HOST|$NEW_RDS_HOST|g")
          changed=true
        fi

        # Replace old CMS RDS host
        if echo "$decoded" | grep -q "$OLD_CMS_RDS_HOST"; then
          decoded=$(echo "$decoded" | sed "s|$OLD_CMS_RDS_HOST|$NEW_RDS_HOST|g")
          changed=true
        fi

        # Replace old RDS password with new (in connection URIs)
        if [ "$NEW_RDS_PASSWORD" != "CHANGE_ME" ]; then
          if echo "$decoded" | grep -q "$OLD_RDS_PASSWORD"; then
            decoded=$(echo "$decoded" | sed "s|$OLD_RDS_PASSWORD|$NEW_RDS_PASSWORD|g")
            changed=true
          fi
          if echo "$decoded" | grep -q "$OLD_CMS_RDS_PASSWORD"; then
            decoded=$(echo "$decoded" | sed "s|$OLD_CMS_RDS_PASSWORD|$NEW_RDS_PASSWORD|g")
            changed=true
          fi
        fi

        # Replace me-central-1 region
        if echo "$decoded" | grep -q "me-central-1"; then
          decoded=$(echo "$decoded" | sed "s|me-central-1|eu-central-1|g")
          changed=true
        fi

        if [ "$changed" = true ]; then
          # Re-encode and write
          new_val=$(echo -n "$decoded" | base64)
          # Preserve original indentation
          indent=$(echo "$line" | sed 's/\S.*//')
          echo "${indent}${key}: ${new_val}" >> "$tmpfile"
          echo "  Updated: $key"
          continue
        fi
      fi
    fi

    echo "$line" >> "$tmpfile"
  done < "$file"

  mv "$tmpfile" "$file"
  echo ""
}

# Patch the 3 files that have old endpoints
for secret_file in \
  "$K8S_DIR/user/secret.yaml" \
  "$K8S_DIR/cli/secret.yaml" \
  "$K8S_DIR/gamify/secrets-gamify.yaml"; do
  if [ -f "$secret_file" ]; then
    patch_secret_file "$secret_file"
  else
    echo "SKIP (not found): $secret_file"
  fi
done

echo "=== Done! ==="
echo ""
echo "NOTE: If you haven't set RDS_PASS, the password in connection URIs"
echo "still has the old value. Set it and re-run:"
echo "  RDS_PASS=your_new_password bash $0"
