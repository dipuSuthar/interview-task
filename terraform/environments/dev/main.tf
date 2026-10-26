terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = ">= 5.81, < 7.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
  # Partial config: bucket/key/region are supplied with -backend-config (see backend.hcl.example).
  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = "${var.project}-${var.environment}"
}

module "network" {
  source             = "../../modules/network"
  name               = local.name
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  az_count           = 2
  single_nat_gateway = var.single_nat_gateway
}

module "security" {
  source            = "../../modules/security"
  name              = local.name
  vpc_id            = module.network.vpc_id
  app_port          = var.app_port
  alb_ingress_cidrs = var.alb_ingress_cidrs
}

module "storage" {
  source        = "../../modules/storage"
  name          = local.name
  force_destroy = var.force_destroy_buckets
}

module "database" {
  source                = "../../modules/database"
  name                  = local.name
  subnet_ids            = module.network.database_subnet_ids
  security_group_id     = module.security.db_sg_id
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  multi_az              = var.db_multi_az
  create_read_replica   = var.create_read_replica
  backup_retention_days = var.backup_retention_days
  deletion_protection   = var.deletion_protection
  skip_final_snapshot   = !var.deletion_protection
  secret_recovery_days  = var.secret_recovery_days
}

module "iam" {
  source         = "../../modules/iam"
  name           = local.name
  db_secret_arn  = module.database.secret_arn
  release_bucket = var.release_bucket
  app_bucket_arn = module.storage.app_bucket_arn
}

module "acm" {
  source                   = "../../modules/acm"
  domain_name              = var.domain_name
  route53_zone_id          = var.route53_zone_id
  existing_certificate_arn = var.certificate_arn
}

module "alb" {
  source              = "../../modules/alb"
  name                = local.name
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids
  security_group_id   = module.security.alb_sg_id
  certificate_arn     = module.acm.certificate_arn
  logs_bucket         = module.storage.alb_logs_bucket_id
  app_port            = var.app_port
  active_color        = var.active_color
  canary_weight       = var.canary_weight
  deletion_protection = var.deletion_protection
}

resource "aws_route53_record" "app" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}

# ---- Blue / green fleets ----
module "compute_blue" {
  source                = "../../modules/compute"
  name                  = local.name
  color                 = "blue"
  region                = var.region
  enabled               = var.blue_enabled
  app_version           = var.blue_version
  instance_type         = var.instance_type
  min_size              = var.asg_min_size
  max_size              = var.asg_max_size
  app_port              = var.app_port
  subnet_ids            = module.network.private_subnet_ids
  security_group_id     = module.security.app_sg_id
  target_group_arn      = module.alb.target_group_arns["blue"]
  instance_profile_name = module.iam.instance_profile_name
  release_bucket        = var.release_bucket
  app_bucket            = module.storage.app_bucket_id
  db_secret_arn         = module.database.secret_arn
}

module "compute_green" {
  source                = "../../modules/compute"
  name                  = local.name
  color                 = "green"
  region                = var.region
  enabled               = var.green_enabled
  app_version           = var.green_version
  instance_type         = var.instance_type
  min_size              = var.asg_min_size
  max_size              = var.asg_max_size
  app_port              = var.app_port
  subnet_ids            = module.network.private_subnet_ids
  security_group_id     = module.security.app_sg_id
  target_group_arn      = module.alb.target_group_arns["green"]
  instance_profile_name = module.iam.instance_profile_name
  release_bucket        = var.release_bucket
  app_bucket            = module.storage.app_bucket_id
  db_secret_arn         = module.database.secret_arn
}
