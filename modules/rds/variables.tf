variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "rds_sg_id" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "snapshot_identifier" {
  type    = string
  default = ""
}

variable "master_username" {
  type      = string
  sensitive = true
}

variable "master_password" {
  type      = string
  sensitive = true
}

variable "multi_az" {
  description = "Enable Multi-AZ (prod=true, staging=false)"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection (prod=true, staging=false for clean destroy)"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (staging=true for clean destroy)"
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights (not supported on db.t4g.medium)"
  type        = bool
  default     = true
}
