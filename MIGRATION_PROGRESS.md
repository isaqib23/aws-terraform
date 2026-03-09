# Migration Progress: UAE (me-central-1) -> Frankfurt (eu-central-1)

**Date:** 2026-03-06
**Account:** 491085410249 (viwell-v2-staging)
**Profile:** viwell-v2-staging

---

## COMPLETED

### 1. Infrastructure Provisioned (Terraform)
All resources created successfully in eu-central-1:

| Resource | Status | Details |
|----------|--------|---------|
| VPC | Done | 3 public + 3 private subnets, 1 NAT GW |
| EKS Cluster | Done | viwell-staging, v1.31, 2x m7g.large nodes Ready |
| RDS | Done | viwell-staging-rds.cbus2c86usep.eu-central-1.rds.amazonaws.com |
| Redis | Done | master.viwell-staging-redis.sz6p15.euc1.cache.amazonaws.com |
| Kafka (MSK) | Done | 3 brokers, b-1/b-2/b-3.viwellstagingkafka.ag5i4i.c3.kafka.eu-central-1.amazonaws.com:9092 |
| ECR | Done | 13 repos under viwell/ |
| S3 (Velero) | Done | viwell-staging-velero-backups |
| ACM Certificate | Done | arn:aws:acm:eu-central-1:491085410249:certificate/8204b105-b663-44db-af65-f3e04e010293 |
| Bastion | Done | 35.158.66.33 (t4g.micro) |
| Security Groups | Done | SG-to-SG references |
| EKS Addons | Done | Pod Identity, EBS CSI, Cluster Autoscaler, LBC, Velero (via Terraform/Helm) |

### 2. kubectl Connected
- Kubeconfig updated: `aws eks update-kubeconfig --name viwell-staging --region eu-central-1 --profile viwell-v2-staging`
- Nodes verified: 2x Ready (ip-10-0-49-144, ip-10-0-83-88)

### 3. SSH Key Imported
- Key `viwell-prod-rds` imported to eu-central-1 in account 491085410249

---

## Issues Encountered & Resolved

### Wrong Account Deployment
- **Problem:** terraform.tfvars accidentally had `aws_profile = "viwell-prod"` (account 867344468263) instead of `viwell-v2-staging` (491085410249)
- **Fix:** `terraform destroy` with wrong profile, delete state, `terraform init` + `terraform apply` with correct profile

### S3 Bucket Already Exists
- **Problem:** `viwell-staging-velero-backups` existed from mixed apply
- **Fix:** `terraform import module.s3_ecr.aws_s3_bucket.velero viwell-staging-velero-backups`

### kubectl 401 Unauthorized
- **Problem:** `kubectl get nodes` returned "the server has asked for the client to provide credentials"
- **Root Cause:** Shell had `AWS_PROFILE=viwell-prod` and hardcoded `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN` env vars that overrode kubeconfig's `AWS_PROFILE=viwell-v2-staging`
- **Fix:** `unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN`
- **Prevention:** Don't export AWS credentials as env vars when using SSO profiles. Check `env | grep AWS` if kubectl auth fails.

### S3 Lifecycle Rule Warning
- **Problem:** `Invalid Attribute Combination` on lifecycle rule
- **Fix:** Added `filter {}` block to lifecycle rule in `modules/s3-ecr/main.tf`

---

## REMAINING (pick up here tomorrow)

### Step 1: Validate ACM Certificate (BLOCKER)
The certificate is pending DNS validation. Add this CNAME record to your Route53 hosted zone for viwell.me:

```
Name:  _2cddab0f1df51476a119b5a0d865cdb8.viwell.me.
Value: _20e5ee414e796f73983073f32ce45b15.zfyfvmchrl.acm-validations.aws.
```

Check status:
```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:eu-central-1:491085410249:certificate/8204b105-b663-44db-af65-f3e04e010293 \
  --region eu-central-1 \
  --profile viwell-v2-staging \
  --query 'Certificate.Status'
```

### Step 2: Update K8s Manifests
Replace old UAE endpoints with new Frankfurt endpoints in all K8s manifests:

| Config | Old (UAE) | New (Frankfurt) |
|--------|-----------|-----------------|
| RDS Host | (old UAE endpoint) | viwell-staging-rds.cbus2c86usep.eu-central-1.rds.amazonaws.com |
| Redis Host | (old UAE endpoint) | master.viwell-staging-redis.sz6p15.euc1.cache.amazonaws.com |
| Kafka Brokers | (old UAE brokers) | b-1.viwellstagingkafka.ag5i4i.c3.kafka.eu-central-1.amazonaws.com:9092,b-2.viwellstagingkafka.ag5i4i.c3.kafka.eu-central-1.amazonaws.com:9092,b-3.viwellstagingkafka.ag5i4i.c3.kafka.eu-central-1.amazonaws.com:9092 |
| ACM ARN | (old UAE cert) | arn:aws:acm:eu-central-1:491085410249:certificate/8204b105-b663-44db-af65-f3e04e010293 |
| ECR Prefix | (old UAE ECR) | 491085410249.dkr.ecr.eu-central-1.amazonaws.com/viwell/ |

### Step 3: Deploy Workloads
```bash
kubectl apply -f <manifests>
kubectl get pods -A  # verify all pods running
```

### Step 4: Update Route53 DNS
Point `*.viwell.me` to the new ALB in eu-central-1.

### Step 5: Update CI/CD
- ECR URLs: `491085410249.dkr.ecr.eu-central-1.amazonaws.com/viwell/<service>`
- Region: `eu-central-1`
- Cluster name: `viwell-staging`

### Step 6: Verify
```bash
curl -I https://user.viwell.me/docs
curl -I https://admin.viwell.me
curl -I https://notification.viwell.me
```

---

## Key Terraform Outputs (for reference)

```
EKS Endpoint:    https://587AD79AD6EA2323DA9DEE535C9A3824.gr7.eu-central-1.eks.amazonaws.com
EKS Cluster:     viwell-staging
Bastion IP:      35.158.66.33
RDS Endpoint:    viwell-staging-rds.cbus2c86usep.eu-central-1.rds.amazonaws.com
Redis Endpoint:  master.viwell-staging-redis.sz6p15.euc1.cache.amazonaws.com
Kafka Brokers:   b-1.viwellstagingkafka.ag5i4i.c3.kafka.eu-central-1.amazonaws.com:9092
                 b-2.viwellstagingkafka.ag5i4i.c3.kafka.eu-central-1.amazonaws.com:9092
                 b-3.viwellstagingkafka.ag5i4i.c3.kafka.eu-central-1.amazonaws.com:9092
ACM ARN:         arn:aws:acm:eu-central-1:491085410249:certificate/8204b105-b663-44db-af65-f3e04e010293
```

## Pre-flight Checklist (before starting tomorrow)

- [ ] `unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN`
- [ ] `aws sso login --profile viwell-v2-staging`
- [ ] `kubectl get nodes` (verify 2 Ready)
- [ ] Check ACM cert status (should be ISSUED if CNAME was added)
