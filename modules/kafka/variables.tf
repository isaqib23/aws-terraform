variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "kafka_sg_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "broker_count" {
  type = number
}

variable "ebs_volume_size" {
  type = number
}
