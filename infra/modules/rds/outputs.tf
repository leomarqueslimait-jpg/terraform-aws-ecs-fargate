output "db_endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.multiaz_rds.address
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.multiaz_rds.db_name
}