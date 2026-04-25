output "rds_secret_arn" {
  description = "ARN of the RDS secret"
  value       = aws_secretsmanager_secret.db.arn
}

output "db_password" {
  description = "Database password"
  value = random_password.db.result
  sensitive = true
}