output "state_bucket" { value = local.state_bucket }
output "release_bucket" { value = local.release_bucket }
output "github_role_arn" { value = aws_iam_role.github_deploy.arn }
output "github_variables_to_set" {
  value = <<-EOT
    AWS_ROLE_ARN    = ${aws_iam_role.github_deploy.arn}
    AWS_REGION      = ${var.region}
    TF_STATE_BUCKET = ${local.state_bucket}
    RELEASE_BUCKET  = ${local.release_bucket}
  EOT
}
