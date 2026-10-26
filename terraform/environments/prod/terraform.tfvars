domain_name     = "app.example.com"
route53_zone_id = "Z0000000000000000000"

environment           = "prod"
vpc_cidr              = "10.30.0.0/16"
single_nat_gateway    = false # one NAT per AZ
instance_type         = "t3.small"
asg_min_size          = 2
asg_max_size          = 6
db_instance_class     = "db.t3.small"
db_multi_az           = true
backup_retention_days = 7
secret_recovery_days  = 7
deletion_protection   = true
force_destroy_buckets = false
