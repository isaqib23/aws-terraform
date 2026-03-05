output "bootstrap_brokers" {
  description = "Plaintext bootstrap brokers"
  value       = aws_msk_cluster.main.bootstrap_brokers
}

output "zookeeper_connect_string" {
  value = aws_msk_cluster.main.zookeeper_connect_string
}

output "cluster_arn" {
  value = aws_msk_cluster.main.arn
}
