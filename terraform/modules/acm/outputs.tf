output "certificate_arn" {
  value = local.create ? one(aws_acm_certificate_validation.this[*].certificate_arn) : var.existing_certificate_arn
}
