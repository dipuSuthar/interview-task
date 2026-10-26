# >>> EDIT these two for your domain (Route 53 hosted zone required for ACM validation) <<<
domain_name     = "app.example.com"
route53_zone_id = "Z0000000000000000000"

# Dev: cheapest settings. release_bucket is injected by CI via TF_VAR_release_bucket.
environment        = "dev"
single_nat_gateway = true
instance_type      = "t3.micro"
db_instance_class  = "db.t3.micro"
db_multi_az        = false
