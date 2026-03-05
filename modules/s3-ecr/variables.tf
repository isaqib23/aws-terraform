variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "force_destroy" {
  description = "Allow destroy of S3 bucket with objects and ECR repos with images (staging=true)"
  type        = bool
  default     = false
}
