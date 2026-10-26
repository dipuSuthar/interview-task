variable "domain_name" { type = string }
variable "route53_zone_id" { type = string }
variable "existing_certificate_arn" {
  type    = string
  default = ""
}
