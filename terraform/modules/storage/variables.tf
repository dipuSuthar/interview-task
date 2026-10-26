variable "name" { type = string }
variable "force_destroy" {
  type    = bool
  default = false
}
variable "log_retention_days" {
  type    = number
  default = 90
}
