# =============================================================================
# Outputs — Used by automation scripts to generate K8s manifests
# =============================================================================

# VPC
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Use these in ALB ingress annotation: alb.ingress.kubernetes.io/subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

# EKS
output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_update_kubeconfig_command" {
  description = "Run this to connect kubectl to the new cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --profile ${var.aws_profile}"
}

output "eks_lb_controller_role_arn" {
  value = module.eks.lb_controller_role_arn
}

output "eks_external_dns_role_arn" {
  value = module.eks.external_dns_role_arn
}

output "eks_cluster_autoscaler_role_arn" {
  value = module.eks.cluster_autoscaler_role_arn
}

output "velero_role_arn" {
  value = module.eks.velero_role_arn
}

# RDS
output "rds_endpoint" {
  description = "Update POSTGRES_HOST_* in configmaps with this value"
  value       = module.rds.address
}

output "rds_port" {
  value = module.rds.port
}

# Redis
output "redis_configuration_endpoint" {
  description = "Update REDIS_HOST in configmaps (cluster mode endpoint)"
  value       = module.redis.configuration_endpoint
}

output "redis_primary_endpoint" {
  value = module.redis.primary_endpoint
}

# Kafka
output "kafka_bootstrap_brokers" {
  description = "Update KAFKA_BROKER in configmaps with this value"
  value       = module.kafka.bootstrap_brokers
}

# Bastion
output "bastion_public_ip" {
  description = "SSH tunnel host for DBeaver/psql access"
  value       = module.bastion.public_ip
}

# ACM
output "acm_certificate_arn" {
  description = "Update alb.ingress.kubernetes.io/certificate-arn with this value"
  value       = module.s3_ecr.acm_certificate_arn
}

output "acm_dns_validation" {
  description = "Add these CNAME records to Route53 to validate the certificate"
  value       = module.s3_ecr.acm_domain_validation_options
}

# ECR
output "ecr_repository_urls" {
  description = "CI/CD image push targets"
  value       = module.s3_ecr.ecr_repository_urls
}

# S3
output "velero_bucket" {
  value = module.s3_ecr.velero_bucket_name
}
