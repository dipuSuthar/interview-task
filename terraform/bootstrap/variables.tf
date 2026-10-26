variable "project" {
  type    = string
  default = "devops-task"
}
variable "region" {
  type    = string
  default = "ap-south-1"
}
variable "github_repo" {
  type        = string
  description = "GitHub repo allowed to deploy, as owner/name (e.g. dilip/aws-devops-task)"
}
variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "Set false if the account already has the GitHub OIDC provider."
}
