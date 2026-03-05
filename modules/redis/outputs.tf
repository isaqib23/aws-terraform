output "configuration_endpoint" {
  description = "Redis cluster configuration endpoint (use this for cluster-aware clients)"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
}

output "primary_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "port" {
  value = 6379
}
