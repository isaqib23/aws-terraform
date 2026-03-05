# Redis Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redis-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-subnet"
  }
}

# Redis Replication Group — match prod (cluster mode with shards + replicas)
resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project_name}-${var.environment}-redis-cluster"
  description          = "ElastiCache cluster for ${var.project_name} ${var.environment}"

  engine               = "redis"
  node_type            = var.node_type
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [var.redis_sg_id]

  # Cluster mode (match prod: 3 shards, 2 replicas each = 9 nodes)
  automatic_failover_enabled = var.cluster_mode_enabled
  multi_az_enabled           = var.cluster_mode_enabled
  num_node_groups            = var.num_node_groups
  replicas_per_node_group    = var.replicas_per_node_group

  # Encryption (match prod)
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  apply_immediately          = true
  auto_minor_version_upgrade = true
  maintenance_window         = "mon:04:00-mon:05:00"

  final_snapshot_identifier = "${var.project_name}-${var.environment}-redis-snapshot"
  snapshot_retention_limit  = 1
  snapshot_window           = "01:00-02:00"

  tags = {
    Name = "${var.project_name}-${var.environment}-redis"
  }
}
