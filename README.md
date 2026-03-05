# Viwell Staging Infrastructure — Frankfurt (eu-central-1)

Migrated from me-central-1 (UAE) due to region outage.

## Architecture

```
                        Internet
                           |
                      [ Route53 ]
                      *.viwell.me
                           |
                   [ ALB (public) ]
                    ports 80, 443
                           |
              +------------+------------+
              |     EKS Cluster         |
              |  (private subnets)      |
              |                         |
              |  App Nodes (m7g.large)  |
              |  Runner Nodes (spot)    |
              +--+------+------+-------+
                 |      |      |
            +----+  +---+  +---+----+
            |       |      |        |
         [ RDS ]  [Redis] [Kafka]  [ ECR ]
         pg 16.6  single   3x      13 repos
         private  node     broker
                           |
              +------------+
              |  Bastion (public)
              |  SSH tunnel to RDS
              +---> DBeaver local
```

## Modules

| Module | Resources | Notes |
|--------|-----------|-------|
| **vpc** | VPC, 3 public + 3 private subnets, 1 NAT GW, IGW | Single NAT (cost saving vs prod's 3) |
| **security-groups** | EKS, ALB, RDS, Redis, Kafka, Bastion SGs | SG-to-SG refs (no CIDR) |
| **eks** | Cluster, 2 node groups, OIDC, Pod Identity, LBC, Autoscaler, CSI drivers | Graviton ARM, Helm addons |
| **rds** | PostgreSQL 16.6, subnet group, monitoring role | Private, enhanced monitoring |
| **redis** | ElastiCache replication group | Single node (staging), cluster mode (prod) |
| **kafka** | MSK cluster, config, CloudWatch logs | PLAINTEXT, 3 brokers |
| **s3-ecr** | Velero S3 bucket, 13 ECR repos, ACM cert | *.viwell.me |
| **bastion** | EC2 t4g.micro with kubectl/helm/terraform | SSH tunnel to RDS |

## Staging vs Prod Sizing

| Resource | Staging | Prod |
|----------|---------|------|
| EKS instances | m7g.large (2vCPU/8GB) | m7g.xlarge (4vCPU/16GB) |
| EKS nodes | 2 desired, 2-4 | 4 desired, 3-7 |
| EKS disk | 100 GiB | 400 GiB |
| RDS | db.t4g.medium, single-AZ | db.r7g.large, multi-AZ |
| RDS storage | 50 GiB | 100 GiB |
| Redis | cache.t4g.medium, 1 node | cache.r7g.large, 9 nodes (3x2 cluster) |
| Kafka | kafka.t3.small, 50GB | kafka.m7g.large, 100GB |
| NAT Gateway | 1 (shared) | 3 (per-AZ HA) |

## Estimated Monthly Cost (Staging)

| Service | Approx. Cost |
|---------|-------------|
| EKS cluster | $73 |
| EKS nodes (2x m7g.large) | ~$140 |
| Runner node (1x m7g.large spot) | ~$25 |
| NAT Gateway | ~$35 |
| RDS (db.t4g.medium, single-AZ) | ~$55 |
| Redis (cache.t4g.medium, 1 node) | ~$45 |
| MSK Kafka (3x kafka.t3.small) | ~$150 |
| Bastion (t4g.micro) | ~$6 |
| S3 + ECR | ~$5 |
| **Total** | **~$534/month** |

## Prerequisites

1. AWS SSO configured: `aws sso login --profile viwell-prod`
2. Terraform >= 1.5.0
3. SSH key imported to eu-central-1: `aws ec2 import-key-pair --key-name viwell-prod-rds --public-key-material fileb://~/.ssh/viwell-prod/rds.pub --region eu-central-1 --profile viwell-prod`

## Quick Start

```bash
cd terraform/environments/staging

# Edit terraform.tfvars — set rds_master_password
vim terraform.tfvars

terraform init
terraform plan
terraform apply
```

## RDS Access via SSH Tunnel (DBeaver)

RDS is in private subnets — access it through the bastion host:

```bash
# Get bastion IP and RDS endpoint
terraform output bastion_public_ip
terraform output rds_endpoint

# SSH tunnel
ssh -i ~/.ssh/viwell-prod/rds -L 5432:<rds-endpoint>:5432 ec2-user@<bastion-ip>

# Now connect DBeaver to localhost:5432
```

### DBeaver Configuration

| Setting | Value |
|---------|-------|
| **SSH Tunnel Host** | `<bastion_public_ip>` |
| **SSH Tunnel Port** | 22 |
| **SSH Username** | ec2-user |
| **SSH Identity File** | ~/.ssh/viwell-prod/rds |
| **DB Host** | localhost (tunneled) |
| **DB Port** | 5432 |
| **DB Name** | your database name |
| **DB User** | postgress_admin |

## Clean Destroy & Re-create

Staging is configured for clean teardown:
- `deletion_protection = false` on RDS
- `skip_final_snapshot = true` on RDS
- `force_destroy = true` on S3 and ECR
- Security groups use `create_before_destroy`

```bash
# Destroy everything cleanly
terraform destroy

# Re-create from scratch
terraform apply
```

No orphaned resources or snapshot name collisions.

## Security

- RDS: private subnets only, accessible from EKS nodes + bastion SG
- Redis: private subnets only, accessible from EKS nodes SG only
- Kafka: private subnets only, accessible from EKS nodes SG only
- Bastion: public subnet, SSH from 0.0.0.0/0 (restrict to office IP in prod)
- All SG references are SG-to-SG (not CIDR-based)
- S3: public access blocked, AES256 encryption, versioning enabled
- EKS: private endpoint + public endpoint, API auth mode

## Post-Apply Steps

See [MIGRATION_RUNBOOK.sh](MIGRATION_RUNBOOK.sh) for the full migration guide:
1. Import SSH key to Frankfurt
2. `terraform apply`
3. Validate ACM certificate (add DNS CNAME records)
4. Connect kubectl to new cluster
5. Update K8s manifests with new endpoints (RDS, Redis, Kafka, ACM ARN, subnet IDs)
6. Deploy workloads
7. Update Route53 DNS
8. Update CI/CD (ECR URLs, region, cluster name)
