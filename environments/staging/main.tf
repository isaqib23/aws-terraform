# =============================================================================
# Viwell Staging Infrastructure — Frankfurt (eu-central-1)
# Migrated from me-central-1 (UAE) due to region outage
# =============================================================================

# --- VPC ---
module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
  environment  = var.environment
}

# --- Security Groups ---
module "security_groups" {
  source = "../../modules/security-groups"

  vpc_id       = module.vpc.vpc_id
  project_name = var.project_name
  environment  = var.environment
}

# --- EKS ---
module "eks" {
  source = "../../modules/eks"

  project_name        = var.project_name
  environment         = var.environment
  cluster_version     = var.eks_cluster_version
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  cluster_sg_id       = module.security_groups.eks_cluster_sg_id
  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
  runner_instance_types = var.runner_instance_types
  runner_desired_size   = var.runner_desired_size
}

# --- RDS PostgreSQL ---
module "rds" {
  source = "../../modules/rds"

  project_name        = var.project_name
  environment         = var.environment
  private_subnet_ids  = module.vpc.private_subnet_ids
  rds_sg_id           = module.security_groups.rds_sg_id
  instance_class      = var.rds_instance_class
  allocated_storage   = var.rds_allocated_storage
  snapshot_identifier = var.rds_snapshot_identifier
  master_username     = var.rds_master_username
  master_password     = var.rds_master_password
}

# --- ElastiCache Redis ---
module "redis" {
  source = "../../modules/redis"

  project_name       = var.project_name
  environment        = var.environment
  private_subnet_ids = module.vpc.private_subnet_ids
  redis_sg_id        = module.security_groups.redis_sg_id
  node_type          = var.redis_node_type
}

# --- MSK Kafka ---
module "kafka" {
  source = "../../modules/kafka"

  project_name       = var.project_name
  environment        = var.environment
  private_subnet_ids = module.vpc.private_subnet_ids
  kafka_sg_id        = module.security_groups.kafka_sg_id
  instance_type      = var.kafka_instance_type
  broker_count       = var.kafka_broker_count
  ebs_volume_size    = var.kafka_ebs_volume_size
}

# --- S3, ECR, ACM Certificate ---
module "s3_ecr" {
  source = "../../modules/s3-ecr"

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name
}

# --- Bastion Host (for SSH tunnel to RDS) ---
module "bastion" {
  source = "../../modules/bastion"

  project_name    = var.project_name
  environment     = var.environment
  instance_type   = var.bastion_instance_type
  key_name        = var.bastion_key_name
  public_subnet_id = module.vpc.public_subnet_ids[0]
  bastion_sg_id   = module.security_groups.bastion_sg_id
}
