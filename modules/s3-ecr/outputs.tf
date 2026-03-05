output "velero_bucket_name" {
  value = aws_s3_bucket.velero.id
}

output "ecr_repository_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.main.arn
}

output "acm_domain_validation_options" {
  value = aws_acm_certificate.main.domain_validation_options
}
