#!/bin/bash
# =============================================================================
# Generate K8s ConfigMaps from Terraform outputs
# Eliminates manual endpoint replacement that was painful in staging
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Reading Terraform outputs ==="
RDS_HOST=$(terraform output -raw rds_endpoint)
REDIS_ENDPOINT=$(terraform output -raw redis_primary_endpoint)
KAFKA_BROKERS=$(terraform output -raw kafka_bootstrap_brokers)
AWS_REGION="eu-central-1"
RDS_PASSWORD="${RDS_PASS:-CHANGE_ME}"
RDS_USER="postgress_admin"

# Strip port from redis endpoint if present
REDIS_HOST=$(echo "$REDIS_ENDPOINT" | cut -d: -f1)

OUTPUT_DIR="$(pwd)/generated-configmaps"
mkdir -p "$OUTPUT_DIR"

echo "RDS:   $RDS_HOST"
echo "Redis: $REDIS_HOST"
echo "Kafka: $KAFKA_BROKERS"
echo ""

# --- postgres-config ---
cat > "$OUTPUT_DIR/postgres-config.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: prod-viwell
data:
  POSTGRES_URI_CENTRAL: postgresql://${RDS_USER}:${RDS_PASSWORD}@${RDS_HOST}:5432/viwell_prod_central
  POSTGRES_USERNAME_CENTRAL: "${RDS_USER}"
  POSTGRES_PASSWORD_CENTRAL: "${RDS_PASSWORD}"
  POSTGRES_DATABASE_CENTRAL: viwell_prod_central
  POSTGRES_HOST_CENTRAL: "${RDS_HOST}"
  POSTGRES_PORT_CENTRAL: "5432"
  POSTGRES_LOGGING_CENTRAL: "true"
  POSTGRES_MAX_QUERY_EXECUTION_TIME_CENTRAL: "1000"
  POSTGRES_URI_UAE: postgresql://${RDS_USER}:${RDS_PASSWORD}@${RDS_HOST}:5432/viwell_prod
  POSTGRES_USERNAME_UAE: "${RDS_USER}"
  POSTGRES_PASSWORD_UAE: "${RDS_PASSWORD}"
  POSTGRES_DATABASE_UAE: viwell_prod
  POSTGRES_HOST_UAE: "${RDS_HOST}"
  POSTGRES_PORT_UAE: "5432"
  POSTGRES_LOGGING_UAE: "true"
  POSTGRES_MAX_QUERY_EXECUTION_TIME_UAE: "1000"
  # KSA stays as external Aliyun DB
  POSTGRES_URI_KSA: "postgresql://master_admin:S%3EeLv78y+sL77d%@pgm-l4vjz313ubsk36t5.pgsql.me-central-1.rds.aliyuncs.com:5432/viwell_prod"
  POSTGRES_USERNAME_KSA: master_admin
  POSTGRES_PASSWORD_KSA: "S%3EeLv78y+sL77d%"
  POSTGRES_DATABASE_KSA: viwell_prod
  POSTGRES_HOST_KSA: "pgm-l4vjz313ubsk36t5.pgsql.me-central-1.rds.aliyuncs.com"
  POSTGRES_PORT_KSA: "5432"
  POSTGRES_LOGGING_KSA: "true"
  POSTGRES_MAX_QUERY_EXECUTION_TIME_KSA: "1000"
  # CI Test databases
  POSTGRES_URI_CENTRAL_TEST: postgresql://${RDS_USER}:${RDS_PASSWORD}@${RDS_HOST}:5432/viwell_prod_ci_central
  POSTGRES_USERNAME_CENTRAL_TEST: "${RDS_USER}"
  POSTGRES_PASSWORD_CENTRAL_TEST: "${RDS_PASSWORD}"
  POSTGRES_DATABASE_CENTRAL_TEST: viwell_prod_ci_central
  POSTGRES_HOST_CENTRAL_TEST: "${RDS_HOST}"
  POSTGRES_PORT_CENTRAL_TEST: "5432"
  POSTGRES_LOGGING_CENTRAL_TEST: "true"
  POSTGRES_MAX_QUERY_EXECUTION_TIME_CENTRAL_TEST: "1000"
  POSTGRES_URI_UAE_TEST: postgresql://${RDS_USER}:${RDS_PASSWORD}@${RDS_HOST}:5432/viwell_prod_ci_uae
  POSTGRES_USERNAME_UAE_TEST: "${RDS_USER}"
  POSTGRES_PASSWORD_UAE_TEST: "${RDS_PASSWORD}"
  POSTGRES_DATABASE_UAE_TEST: viwell_prod_ci_uae
  POSTGRES_HOST_UAE_TEST: "${RDS_HOST}"
  POSTGRES_PORT_UAE_TEST: "5432"
  POSTGRES_LOGGING_UAE_TEST: "true"
  POSTGRES_MAX_QUERY_EXECUTION_TIME_UAE_TEST: "1000"
  POSTGRES_URI_KSA_TEST: postgresql://${RDS_USER}:${RDS_PASSWORD}@${RDS_HOST}:5432/viwell_prod_ci_ksa
  POSTGRES_USERNAME_KSA_TEST: "${RDS_USER}"
  POSTGRES_PASSWORD_KSA_TEST: "${RDS_PASSWORD}"
  POSTGRES_DATABASE_KSA_TEST: viwell_prod_ci_ksa
  POSTGRES_HOST_KSA_TEST: "${RDS_HOST}"
  POSTGRES_PORT_KSA_TEST: "5432"
  POSTGRES_LOGGING_KSA_TEST: "true"
  POSTGRES_MAX_QUERY_EXECUTION_TIME_KSA_TEST: "1000"
  POSTGRES_SSL_ENABLED_KSA: "false"
  API_ENV: Production
EOF

# --- redis-config ---
cat > "$OUTPUT_DIR/redis-config.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: prod-viwell
data:
  REDIS_PORT: "6379"
  REDIS_HOST: "${REDIS_HOST}"
  REDIS_URI: "${REDIS_HOST}:6379"
EOF

# --- kafka-config ---
cat > "$OUTPUT_DIR/kafka-config.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-config
  namespace: prod-viwell
data:
  KAFKA_BROKER: "${KAFKA_BROKERS}"
  KAFKA_CLIENT_ID: "app-client"
  KAFKA_CONSUMER_GROUP_ID: "notifications-prod"
  KAFKA_REQUEST_TIMEOUT: "30000"
  KAFKA_CONNECTION_TIMEOUT: "3000"
  KAFKA_INITIAL_RETRY_TIME: "300"
  KAFKA_RETRIES: "5"
  KAFKA_MAX_POLL_RECORDS: "100"
  KAFKA_MAX_PARTITION_FETCH_BYTES: "1048576"
  KAFKA_MAX_POLL_INTERVAL_MS: "300000"
  KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
  KAFKA_DELETE_TOPIC_ENABLE: "true"
  KAFKA_TOPIC_ENV: "prod"
EOF

# --- elasticsearch-config (cluster-local, no external endpoint) ---
cat > "$OUTPUT_DIR/elasticsearch-config.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: elasticsearch-config
  namespace: prod-viwell
data:
  ELASTIC_SEARCH_NODE: "http://elasticsearch-master.elastic-prod.svc.cluster.local:9200"
  ELASTIC_SEARCH_HOST: "http://elasticsearch-master.elastic-prod.svc.cluster.local:9200"
  ELASTIC_SEARCH_PORT: "9200"
  ELASTIC_SEARCH_PROTOCOL: "https"
  ELASTIC_SEARCH_CONTENT_INDEX: "content_index"
EOF

# --- aws-s3-config ---
cat > "$OUTPUT_DIR/s3-config.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-s3-config
  namespace: prod-viwell
data:
  AWS_REGION: "${AWS_REGION}"
  AWS_S3_BUCKET_NAME: "viwell-dev-bucket-assets"
  AWS_S3_BUCKET_URL: "arn:aws:s3:::viwell-dev-bucket-assets"
  AWS_S3_BUCKET_ACL: "public-read"
  STORAGE_TYPE: "S3"
EOF

echo "=== ConfigMaps generated in $OUTPUT_DIR ==="
echo "Apply with: kubectl apply -f $OUTPUT_DIR/"
