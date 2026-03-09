variable "vpc_id" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "bastion_allowed_cidrs" {
  description = "CIDRs allowed to SSH to bastion (restrict to office IP for production)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
