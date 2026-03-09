variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "aws_profile" {
  type    = string
  default = "viwell-prod"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "project_name" {
  type    = string
  default = "viwell"
}

# VPC
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "nat_gateway_count" {
  description = "Number of NAT Gateways (3 for prod HA — one per AZ)"
  type        = number
  default     = 3
}

# EKS
variable "eks_cluster_version" {
  type    = string
  default = "1.31"
}

variable "eks_node_instance_types" {
  type    = list(string)
  default = ["m7g.xlarge"] # Graviton ARM, 4 vCPU 16GB — production sized
}

variable "eks_node_desired_size" {
  type    = number
  default = 4
}

variable "eks_node_min_size" {
  type    = number
  default = 3
}

variable "eks_node_max_size" {
  type    = number
  default = 8
}

variable "eks_node_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 400
}

variable "runner_instance_types" {
  type    = list(string)
  default = ["m7g.large"]
}

variable "runner_desired_size" {
  type    = number
  default = 1
}

# RDS
variable "rds_instance_class" {
  type    = string
  default = "db.m7g.large" # Graviton ARM, 2 vCPU 8GB
}

variable "rds_snapshot_identifier" {
  description = "Snapshot ARN to restore from (cross-region copy from me-central-1)"
  type        = string
  default     = ""
}

variable "rds_allocated_storage" {
  type    = number
  default = 100
}

variable "rds_max_allocated_storage" {
  description = "Max storage for RDS auto-scaling"
  type        = number
  default     = 500
}

variable "rds_master_username" {
  type      = string
  default   = "postgress_admin"
  sensitive = true
}

variable "rds_master_password" {
  type      = string
  sensitive = true
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = true
}

# Redis
variable "redis_node_type" {
  type    = string
  default = "cache.m7g.large" # Graviton ARM, 6.38GB
}

variable "redis_cluster_mode_enabled" {
  description = "Enable Redis cluster mode"
  type        = bool
  default     = true
}

variable "redis_num_node_groups" {
  description = "Number of shards"
  type        = number
  default     = 3
}

variable "redis_replicas_per_node_group" {
  description = "Replicas per shard"
  type        = number
  default     = 2
}

# Kafka / MSK
variable "kafka_instance_type" {
  type    = string
  default = "kafka.m7g.large" # Graviton ARM, 8GB
}

variable "kafka_broker_count" {
  type    = number
  default = 3
}

variable "kafka_ebs_volume_size" {
  type    = number
  default = 100
}

# Bastion
variable "bastion_key_name" {
  type    = string
  default = "viwell-prod-rds"
}

variable "bastion_instance_type" {
  type    = string
  default = "t4g.micro"
}

# Security
variable "bastion_allowed_cidrs" {
  description = "CIDRs allowed to SSH to bastion (set to office IP for production)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # TODO: restrict to office IP e.g. ["203.0.113.10/32"]
}

# Domain
variable "domain_name" {
  type    = string
  default = "viwell.tech"
}
