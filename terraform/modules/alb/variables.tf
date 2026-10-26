variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "certificate_arn" { type = string }
variable "logs_bucket" { type = string }
variable "app_port" {
  type    = number
  default = 3000
}
variable "health_check_path" {
  type    = string
  default = "/health"
}
variable "active_color" {
  type    = string
  default = "blue"
  validation {
    condition     = contains(["blue", "green"], var.active_color)
    error_message = "active_color must be blue or green."
  }
}
variable "canary_weight" {
  type        = number
  default     = 0
  description = "Percent of traffic sent to the inactive colour (0 = none)."
  validation {
    condition     = var.canary_weight >= 0 && var.canary_weight <= 100
    error_message = "canary_weight must be 0-100."
  }
}
variable "deletion_protection" {
  type    = bool
  default = false
}
