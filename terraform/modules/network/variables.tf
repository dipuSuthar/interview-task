variable "name" { type = string }
variable "region" { type = string }
variable "vpc_cidr" { type = string }
variable "az_count" {
  type    = number
  default = 2
}
variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "true = one shared NAT (cheaper); false = one NAT per AZ (HA)."
}
