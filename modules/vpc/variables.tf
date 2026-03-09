variable "vpc_cidr" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "nat_gateway_count" {
  description = "Number of NAT Gateways (1 for staging, 3 for prod HA — one per AZ)"
  type        = number
  default     = 1
}
