output "app_bucket_id" { value = aws_s3_bucket.app.id }
output "app_bucket_arn" { value = aws_s3_bucket.app.arn }
output "alb_logs_bucket_id" {
  value      = aws_s3_bucket.alb_logs.id
  depends_on = [aws_s3_bucket_policy.alb_logs] # policy must exist before the ALB enables logging
}
