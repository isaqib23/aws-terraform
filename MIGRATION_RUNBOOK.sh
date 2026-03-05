#!/bin/bash
# =============================================================================
# VIWELL MIGRATION RUNBOOK: me-central-1 (UAE) → eu-central-1 (Frankfurt)
# =============================================================================
# Run each step manually. This is a guide, NOT meant to be executed as a script.
# =============================================================================

# ============================================================
# STEP 0: Prerequisites
# ============================================================

# Install Terraform (if not installed)
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify AWS SSO login
aws sso login --profile viwell-v2-staging
aws sts get-caller-identity --profile viwell-v2-staging

# ============================================================
# STEP 1: BACKUP DATA (Do this FIRST — even if UAE is degraded)
# ============================================================

# 1a. RDS Snapshot — create in UAE region
aws rds create-db-snapshot \
  --db-instance-identifier rds-viwell-v2 \
  --db-snapshot-identifier viwell-pre-migration-$(date +%Y%m%d) \
  --region me-central-1 \
  --profile viwell-v2-staging

# Wait for snapshot to complete
aws rds wait db-snapshot-available \
  --db-snapshot-identifier viwell-pre-migration-$(date +%Y%m%d) \
  --region me-central-1 \
  --profile viwell-v2-staging

# 1b. Copy snapshot to Frankfurt
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:me-central-1:867344468263:snapshot:viwell-pre-migration-$(date +%Y%m%d) \
  --target-db-snapshot-identifier viwell-pre-migration-$(date +%Y%m%d) \
  --source-region me-central-1 \
  --region eu-central-1 \
  --profile viwell-v2-staging

# 1c. Velero backup (if UAE cluster is still reachable)
kubectl config use-context <your-uae-context>
velero backup create pre-migration-full --wait

# 1d. S3 data sync (if needed)
aws s3 sync s3://your-uae-bucket s3://your-frankfurt-bucket \
  --source-region me-central-1 \
  --region eu-central-1 \
  --profile viwell-v2-staging

# ============================================================
# STEP 2: CREATE SSH KEY PAIR IN FRANKFURT
# ============================================================

# Import your existing key or create new one
aws ec2 import-key-pair \
  --key-name viwell-prod-rds \
  --public-key-material fileb://~/.ssh/viwell-prod/rds.pub \
  --region eu-central-1 \
  --profile viwell-v2-staging

# ============================================================
# STEP 3: TERRAFORM — PROVISION INFRASTRUCTURE
# ============================================================

cd /Users/rao/work/misc/aws/terraform/environments/staging

# 3a. Update terraform.tfvars:
#   - Set rds_master_password to your actual password
#   - Uncomment rds_snapshot_identifier once snapshot copy is done

# 3b. Initialize and plan
terraform init
terraform plan -out=migration.plan

# 3c. Review the plan carefully, then apply
terraform apply migration.plan

# 3d. Save outputs — you'll need these for K8s manifests
terraform output -json > /Users/rao/work/misc/aws/terraform/outputs.json

# ============================================================
# STEP 4: VALIDATE ACM CERTIFICATE
# ============================================================

# Terraform will output DNS validation records.
# Add these CNAME records to your Route53 hosted zone for viwell.me
# The certificate must be validated before the ALB ingress will work.

# Check validation status:
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --region eu-central-1 \
  --profile viwell-v2-staging \
  --query 'Certificate.Status'

# ============================================================
# STEP 5: CONNECT TO NEW EKS CLUSTER
# ============================================================

# This command comes from terraform output
aws eks update-kubeconfig \
  --name viwell-staging \
  --region eu-central-1 \
  --profile viwell-v2-staging

kubectl get nodes  # verify nodes are Ready

# ============================================================
# STEP 6: INSTALL EKS ADD-ONS (Helm)
# ============================================================

# 6a. AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=viwell-staging \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw eks_lb_controller_role_arn)

# 6b. NGINX Ingress Controller (if used alongside ALB)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

# 6c. External DNS
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns
helm install external-dns external-dns/external-dns \
  -n kube-system \
  --set provider=aws \
  --set domainFilters[0]=viwell.me \
  --set aws.region=eu-central-1

# 6d. Velero
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero \
  -n velero --create-namespace \
  --set configuration.provider=aws \
  --set configuration.backupStorageLocation.bucket=$(terraform output -raw velero_bucket) \
  --set configuration.backupStorageLocation.config.region=eu-central-1 \
  --set configuration.volumeSnapshotLocation.config.region=eu-central-1 \
  --set serviceAccount.server.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw velero_role_arn) \
  --set initContainers[0].name=velero-plugin-for-aws \
  --set initContainers[0].image=velero/velero-plugin-for-aws:v1.9.0 \
  --set initContainers[0].volumeMounts[0].mountPath=/target \
  --set initContainers[0].volumeMounts[0].name=plugins

# 6e. Kubernetes Dashboard
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  -n kubernetes-dashboard --create-namespace

# ============================================================
# STEP 7: UPDATE K8S MANIFESTS WITH NEW ENDPOINTS
# ============================================================

# You need to update these values from terraform output:
#
# WHAT TO UPDATE                        | WHERE (file in k8s_v2_staging-main)
# --------------------------------------|----------------------------------------
# RDS endpoint                          | configmap/rds-common.yaml (all POSTGRES_HOST_*)
#                                       | configmap/rds-wearable.yaml
# Redis endpoint                        | All secret.yaml files with REDIS_HOST
# Kafka bootstrap brokers               | All secret.yaml files with KAFKA_BROKERS
# ACM certificate ARN                   | ingress/ingress.yaml (certificate-arn annotation)
# Subnet IDs (3 public)                 | ingress/ingress.yaml (subnets annotation)
# Bastion IP                            | Your DBeaver SSH tunnel config
#
# Use this to get all values:
echo "=== RDS Endpoint ==="
terraform output rds_endpoint
echo "=== Redis Endpoint ==="
terraform output redis_endpoint
echo "=== Kafka Brokers ==="
terraform output kafka_bootstrap_brokers
echo "=== ACM Cert ARN ==="
terraform output acm_certificate_arn
echo "=== Public Subnets (for ALB) ==="
terraform output public_subnet_ids
echo "=== Bastion IP ==="
terraform output bastion_public_ip

# ============================================================
# STEP 8: DEPLOY K8S WORKLOADS
# ============================================================

K8S_DIR="/Users/rao/work/misc/aws/k8s_v2_staging-main"

# Apply configmaps first
kubectl apply -f $K8S_DIR/configmap/

# Apply namespaces
kubectl apply -f $K8S_DIR/wearable/ns.yaml
kubectl apply -f $K8S_DIR/service-user-test/ns.yaml

# Apply secrets (update endpoints first!)
kubectl apply -f $K8S_DIR/service-notification/secret.yaml
kubectl apply -f $K8S_DIR/service-gamify/secrets-gamify.yaml
kubectl apply -f $K8S_DIR/cms/secret.yaml
kubectl apply -f $K8S_DIR/wearable/secret.yaml
kubectl apply -f $K8S_DIR/wearable-process/secret.yaml
kubectl apply -f $K8S_DIR/payment-service/secret.yml
kubectl apply -f $K8S_DIR/replication/secret.yaml
kubectl apply -f $K8S_DIR/replication/secrets-xoxo.yaml
kubectl apply -f $K8S_DIR/service-user-test/secret.yaml
kubectl apply -f $K8S_DIR/super-web-admin/secret.yaml
kubectl apply -f $K8S_DIR/service-cli/cli-secret.yaml

# Apply services and deployments
for dir in service-notification service-gamify cms wearable wearable-process payment-service replication service-user-test super-web-admin web-admin service-cli; do
  echo "Deploying $dir..."
  kubectl apply -f $K8S_DIR/$dir/
done

# Apply cron jobs
kubectl apply -f $K8S_DIR/service-cli/jobs/
kubectl apply -f $K8S_DIR/service-user-test/cron-*.yaml

# Apply ingress LAST (after ALB controller is running)
kubectl apply -f $K8S_DIR/ingress/ingress.yaml

# ============================================================
# STEP 9: UPDATE ROUTE53 DNS
# ============================================================

# After the ALB is created, get its hostname:
kubectl get ingress viwell-preprod-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Update Route53 records for all your subdomains to point to the new ALB:
# user.viwell.me, notification.viwell.me, wearable.viwell.me, cli.viwell.me,
# org.viwell.me, admin.viwell.me, cms.viwell.me, gamify.viwell.me,
# dashboard.viwell.me, lago.viwell.me, lago-api.viwell.me, es.viwell.me

# ============================================================
# STEP 10: UPDATE LOCAL RDS ACCESS (DBeaver SSH Tunnel)
# ============================================================

# In DBeaver > SSH Tunnel settings, update:
# - Tunnel host: <bastion_public_ip from terraform output>
# - Tunnel port: 22
# - Username: ec2-user
# - Identity file: /Users/arslan/.ssh/viwell-prod/rds (same key)
#
# In DBeaver > Connection settings, update:
# - Host: <rds_endpoint from terraform output>
# - Port: 5432
# - Database/User/Password: same as before

# ============================================================
# STEP 11: UPDATE CI/CD (GitHub Runner)
# ============================================================

# Deploy GitHub runner to new cluster
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
kubectl apply -f $K8S_DIR/additional-services/github_runner/

# Update GitHub Actions workflows:
# - ECR repository URLs → new Frankfurt ECR URLs
# - EKS cluster name → viwell-staging
# - AWS region → eu-central-1

# ============================================================
# STEP 12: VERIFY EVERYTHING
# ============================================================

echo "=== Nodes ==="
kubectl get nodes -o wide
echo "=== Pods ==="
kubectl get pods --all-namespaces
echo "=== Services ==="
kubectl get svc --all-namespaces
echo "=== Ingress ==="
kubectl get ingress
echo "=== Check ALB ==="
kubectl describe ingress viwell-preprod-lb

# Test endpoints
curl -I https://user.viwell.me/docs
curl -I https://admin.viwell.me
curl -I https://notification.viwell.me

echo "Migration complete! 🎉"
