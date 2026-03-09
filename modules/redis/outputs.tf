output "configuration_endpoint" {
  description = "Redis cluster configuration endpoint (only available in cluster mode)"
  value       = var.cluster_mode_enabled ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address
}

output "primary_endpoint" {
  description = "Redis primary endpoint (null in cluster mode — use configuration_endpoint instead)"
  value       = try(aws_elasticache_replication_group.main.primary_endpoint_address, "")
}

output "port" {
  value = 6379
}
