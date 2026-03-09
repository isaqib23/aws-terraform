# Velero Backup Bucket
resource "aws_s3_bucket" "velero" {
  bucket        = "${var.project_name}-${var.environment}-velero-backups"
  force_destroy = var.force_destroy

  tags = {
    Name = "${var.project_name}-${var.environment}-velero-backups"
  }
}

resource "aws_s3_bucket_public_access_block" "velero" {
  bucket = aws_s3_bucket.velero.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id
  rule {
    id     = "cleanup-old-backups"
    status = "Enabled"
    filter {}
    expiration {
      days = 30
    }
  }
}

# ECR Repositories for your microservices
locals {
  ecr_repos = [
    "viwell-user",
    "viwell-notification",
    "viwell-wearable",
    "viwell-wearable-process",
    "viwell-cli",
    "viwell-gamify",
    "viwell-payment",
    "viwell-cms",
    "viwell-replication",
    "viwell-admin",
    "viwell-super-admin",
    "viwell-web-admin",
    "viwell-user-test",
  ]
}

resource "aws_ecr_repository" "services" {
  for_each = toset(local.ecr_repos)

  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.force_destroy

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = each.key
  }
}

# Lifecycle policy — keep last 10 images to save storage cost
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# ACM Certificate for *.viwell.me in Frankfurt
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cert"
  }
}
