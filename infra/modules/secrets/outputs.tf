output "rds_secret_arn" {
    description = "ARN of the RDS secret"
  value = aws_secretsmanager_secret.db.arn
}