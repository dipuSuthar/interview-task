variable "name" { type = string }
variable "color" { type = string }
variable "region" { type = string }
variable "enabled" {
  type        = bool
  description = "false scales this colour to zero (idle side of blue/green)."
}
variable "app_version" { type = string }
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "min_size" {
  type    = number
  default = 2
}
variable "max_size" {
  type    = number
  default = 4
}
variable "app_port" {
  type    = number
  default = 3000
}
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "target_group_arn" { type = string }
variable "instance_profile_name" { type = string }
variable "release_bucket" { type = string }
variable "app_bucket" { type = string }
variable "db_secret_arn" { type = string }
variable "node_package" {
  type        = string
  default     = "nodejs22"
  description = "Amazon Linux 2023 Node.js package (check: dnf search nodejs)."
}
