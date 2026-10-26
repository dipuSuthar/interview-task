resource "random_password" "master" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+" # excludes / @ " and space, which MySQL/RDS reject
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.subnet_ids
  tags       = { Name = "${var.name}-db-subnets" }
}

resource "aws_db_instance" "primary" {
  identifier = "${var.name}-mysql"

  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true # encryption at rest (AWS-managed KMS key)

  db_name  = var.db_name
  username = var.username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period    = var.backup_retention_days
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "${var.name}-mysql-final"
  apply_immediately          = true

  lifecycle {
    ignore_changes = [engine_version]
  }
}

resource "aws_db_instance" "replica" {
  count               = var.create_read_replica ? 1 : 0
  identifier          = "${var.name}-mysql-replica"
  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = var.instance_class

  vpc_security_group_ids     = [var.security_group_id]
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  skip_final_snapshot        = true
  apply_immediately          = true

  lifecycle {
    ignore_changes = [engine_version]
  }
}

# Credentials live only in Secrets Manager; instances read them at runtime via their IAM role.
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name}/db-credentials"
  description             = "MySQL credentials for ${var.name}"
  recovery_window_in_days = var.secret_recovery_days
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username  = var.username
    password  = random_password.master.result
    host      = aws_db_instance.primary.address
    read_host = var.create_read_replica ? aws_db_instance.replica[0].address : aws_db_instance.primary.address
    port      = aws_db_instance.primary.port
    dbname    = var.db_name
  })
}
