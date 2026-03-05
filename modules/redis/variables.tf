variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "redis_sg_id" {
  type = string
}

variable "node_type" {
  type = string
}

variable "cluster_mode_enabled" {
  description = "Enable cluster mode with failover and multi-AZ"
  type        = bool
  default     = true
}

variable "num_node_groups" {
  description = "Number of shards (match prod: 3)"
  type        = number
  default     = 3
}

variable "replicas_per_node_group" {
  description = "Replicas per shard (match prod: 2)"
  type        = number
  default     = 2
}
