output "eks_cluster_sg_id" {
  value = aws_security_group.eks_cluster.id
}

output "eks_nodes_sg_id" {
  value = aws_security_group.eks_nodes.id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "redis_sg_id" {
  value = aws_security_group.redis.id
}

output "kafka_sg_id" {
  value = aws_security_group.kafka.id
}

output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}
