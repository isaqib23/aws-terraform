#!/bin/bash
# =============================================================================
# Patch K8s secret files: replace old UAE RDS endpoint with new Frankfurt RDS
# Also updates aws_region from me-central-1 to eu-central-1
#
# Strategy: encode old/new values to base64 and do direct sed replacement.
# This avoids any YAML parsing and cannot corrupt file formatting.
#
# Safe to run multiple times (idempotent).
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
K8S_DIR="$REPO_ROOT/k8s_v2_prod-main"

# Read new RDS endpoint from Terraform
NEW_RDS_HOST=$(terraform output -raw rds_endpoint)
NEW_RDS_PASSWORD="${RDS_PASS:-CHANGE_ME}"

# Old UAE values (plaintext)
OLD_RDS_HOST="rds-viwell-v2-master-prod.c7mu0u2aezg4.me-central-1.rds.amazonaws.com"
OLD_RDS_PASSWORD="bRs74Dr31fSd"
OLD_CMS_RDS_HOST="rds-viwell-v2.cjiqyeg0e6dk.me-central-1.rds.amazonaws.com"
OLD_CMS_RDS_PASSWORD="aRs743sfSd"

echo "=== Patching K8s secrets with Frankfurt RDS endpoint ==="
echo "Old RDS: $OLD_RDS_HOST"
echo "New RDS: $NEW_RDS_HOST"
echo ""

# Build base64-encoded search/replace pairs
# Each pair: OLD_B64 -> NEW_B64
declare -a REPLACEMENTS=()

add_replacement() {
  local old_plain="$1"
  local new_plain="$2"
  local old_b64 new_b64
  old_b64=$(echo -n "$old_plain" | base64)
  new_b64=$(echo -n "$new_plain" | base64)
  if [ "$old_b64" != "$new_b64" ]; then
    REPLACEMENTS+=("$old_b64|$new_b64|$old_plain -> $new_plain")
  fi
}

# Host replacements
add_replacement "$OLD_RDS_HOST" "$NEW_RDS_HOST"
add_replacement "$OLD_CMS_RDS_HOST" "$NEW_RDS_HOST"

# Region replacement
add_replacement "me-central-1" "eu-central-1"

# Password replacements (only if RDS_PASS is set)
if [ "$NEW_RDS_PASSWORD" != "CHANGE_ME" ]; then
  add_replacement "$OLD_RDS_PASSWORD" "$NEW_RDS_PASSWORD"
  add_replacement "$OLD_CMS_RDS_PASSWORD" "$NEW_RDS_PASSWORD"
fi

# Now we also need to handle values where the host/region appears INSIDE a longer
# base64 string (e.g. a full connection URI). For these, we decode each base64
# value in the file, do the replacement in plaintext, then re-encode.
# But since base64 encoding depends on byte alignment, a substring replacement on
# base64 won't work for embedded values. So we handle full-value replacements too.

patch_file() {
  local file="$1"
  local changed=false
  local tmpfile
  tmpfile=$(mktemp)

  echo "Patching: $file"

  while IFS= read -r line; do
    # Only process data lines (indented key: value, not comments/metadata)
    if echo "$line" | grep -qE '^\s+[A-Za-z_][A-Za-z0-9_-]*:\s' && \
       ! echo "$line" | grep -qE '^\s*#' && \
       ! echo "$line" | grep -qE '^\s*(metadata|name|namespace|kind|apiVersion|data|type)\s*:'; then

      # Extract key and value preserving exact formatting
      local key val indent
      indent=$(echo "$line" | sed 's/[^ ].*//')
      key=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -d: -f1)
      val=$(echo "$line" | sed 's/^[^:]*:[[:space:]]*//' | tr -d ' "')

      # Try to decode the base64 value
      local decoded
      decoded=$(echo "$val" | base64 -d 2>/dev/null) || decoded=""

      if [ -n "$decoded" ]; then
        local new_decoded="$decoded"
        local val_changed=false

        # Replace old hosts
        if echo "$new_decoded" | grep -qF "$OLD_RDS_HOST"; then
          new_decoded=$(echo "$new_decoded" | sed "s|$OLD_RDS_HOST|$NEW_RDS_HOST|g")
          val_changed=true
        fi
        if echo "$new_decoded" | grep -qF "$OLD_CMS_RDS_HOST"; then
          new_decoded=$(echo "$new_decoded" | sed "s|$OLD_CMS_RDS_HOST|$NEW_RDS_HOST|g")
          val_changed=true
        fi

        # Replace region
        if echo "$new_decoded" | grep -qF "me-central-1"; then
          new_decoded=$(echo "$new_decoded" | sed "s|me-central-1|eu-central-1|g")
          val_changed=true
        fi

        # Replace passwords (only if RDS_PASS is set)
        if [ "$NEW_RDS_PASSWORD" != "CHANGE_ME" ]; then
          if echo "$new_decoded" | grep -qF "$OLD_RDS_PASSWORD"; then
            new_decoded=$(echo "$new_decoded" | sed "s|$OLD_RDS_PASSWORD|$NEW_RDS_PASSWORD|g")
            val_changed=true
          fi
          if echo "$new_decoded" | grep -qF "$OLD_CMS_RDS_PASSWORD"; then
            new_decoded=$(echo "$new_decoded" | sed "s|$OLD_CMS_RDS_PASSWORD|$NEW_RDS_PASSWORD|g")
            val_changed=true
          fi
        fi

        if [ "$val_changed" = true ]; then
          local new_val
          new_val=$(echo -n "$new_decoded" | base64)
          echo "${indent}${key}: ${new_val}" >> "$tmpfile"
          echo "  Updated: $key"
          changed=true
          continue
        fi
      fi
    fi

    # Pass through unchanged
    echo "$line" >> "$tmpfile"
  done < "$file"

  if [ "$changed" = true ]; then
    mv "$tmpfile" "$file"
  else
    rm -f "$tmpfile"
    echo "  (no changes needed)"
  fi
  echo ""
}

# Patch the 3 files that have old endpoints
for secret_file in \
  "$K8S_DIR/user/secret.yaml" \
  "$K8S_DIR/cli/secret.yaml" \
  "$K8S_DIR/gamify/secrets-gamify.yaml"; do
  if [ -f "$secret_file" ]; then
    patch_file "$secret_file"
  else
    echo "SKIP (not found): $secret_file"
  fi
done

echo "=== Done! ==="
echo ""
echo "NOTE: If you haven't set RDS_PASS, the password in connection URIs"
echo "still has the old value. Set it and re-run:"
echo "  RDS_PASS=your_new_password bash $0"
