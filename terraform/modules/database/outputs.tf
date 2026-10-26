output "secret_arn" { value = aws_secretsmanager_secret.db.arn }
output "primary_endpoint" { value = aws_db_instance.primary.address }
output "replica_endpoint" {
  value = var.create_read_replica ? aws_db_instance.replica[0].address : null
}
