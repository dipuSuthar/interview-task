variable "project" {
  type    = string
  default = "devops-task"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "region" {
  type    = string
  default = "ap-south-1"
}

# ---- Networking ----
variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}
variable "single_nat_gateway" {
  type    = bool
  default = true
}
variable "alb_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

# ---- DNS / TLS (a domain you control in Route 53 is required for ACM + HTTPS) ----
variable "domain_name" {
  type        = string
  description = "FQDN for the app, e.g. app.example.com"
}
variable "route53_zone_id" {
  type        = string
  description = "Hosted zone id containing domain_name"
}
variable "certificate_arn" {
  type        = string
  default     = ""
  description = "Optional: reuse an existing ACM cert instead of creating one."
}

# ---- Compute ----
variable "release_bucket" {
  type        = string
  description = "S3 bucket (from bootstrap) holding releases/<version>.tar.gz"
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "app_port" {
  type    = number
  default = 3000
}
variable "asg_min_size" {
  type    = number
  default = 2
}
variable "asg_max_size" {
  type    = number
  default = 4
}

# ---- Blue / green state (the CI/CD pipeline drives these) ----
variable "active_color" {
  type    = string
  default = "blue"
  validation {
    condition     = contains(["blue", "green"], var.active_color)
    error_message = "active_color must be blue or green."
  }
}
variable "blue_enabled" {
  type    = bool
  default = true
}
variable "green_enabled" {
  type    = bool
  default = false
}
variable "blue_version" {
  type    = string
  default = "initial"
}
variable "green_version" {
  type    = string
  default = "initial"
}
variable "canary_weight" {
  type    = number
  default = 0
}

# ---- Database ----
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "db_allocated_storage" {
  type    = number
  default = 20
}
variable "db_multi_az" {
  type    = bool
  default = false
}
variable "create_read_replica" {
  type    = bool
  default = true
}
variable "backup_retention_days" {
  type    = number
  default = 1
}
variable "secret_recovery_days" {
  type    = number
  default = 0
}

# ---- Safety switches ----
variable "deletion_protection" {
  type    = bool
  default = false
}
variable "force_destroy_buckets" {
  type    = bool
  default = true
}
