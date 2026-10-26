variable "name" { type = string }
variable "vpc_id" { type = string }
variable "app_port" {
  type    = number
  default = 3000
}
variable "alb_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
