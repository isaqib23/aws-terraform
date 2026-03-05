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
  default = "staging"
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

# EKS
variable "eks_cluster_version" {
  type    = string
  default = "1.31" # Match prod
}

variable "eks_node_instance_types" {
  type    = list(string)
  default = ["m7g.large"] # Graviton ARM, right-sized for staging
}

variable "eks_node_desired_size" {
  type    = number
  default = 2
}

variable "eks_node_min_size" {
  type    = number
  default = 2
}

variable "eks_node_max_size" {
  type    = number
  default = 4
}

variable "eks_node_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 100
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
  default = "db.t4g.medium" # Graviton, right-sized for staging
}

variable "rds_snapshot_identifier" {
  description = "Snapshot ARN to restore from (cross-region copy from me-central-1)"
  type        = string
  default     = ""
}

variable "rds_allocated_storage" {
  type    = number
  default = 50
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
  default     = false
}

# Redis
variable "redis_node_type" {
  type    = string
  default = "cache.t4g.medium" # Graviton, right-sized for staging
}

variable "redis_cluster_mode_enabled" {
  description = "Enable Redis cluster mode"
  type        = bool
  default     = false
}

variable "redis_num_node_groups" {
  description = "Number of shards"
  type        = number
  default     = 1
}

variable "redis_replicas_per_node_group" {
  description = "Replicas per shard"
  type        = number
  default     = 0
}

# Kafka / MSK
variable "kafka_instance_type" {
  type    = string
  default = "kafka.t3.small" # right-sized for staging
}

variable "kafka_broker_count" {
  type    = number
  default = 3
}

variable "kafka_ebs_volume_size" {
  type    = number
  default = 50
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

# Domain
variable "domain_name" {
  type    = string
  default = "viwell.me"
}
