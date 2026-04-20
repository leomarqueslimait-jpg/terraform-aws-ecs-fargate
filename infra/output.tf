output "repository_url" {
  description = "URL of the ECR repository"
  value = module.ecr.repository_url
}

output "repository_name" {
  description = "Name of the ECR repository"
  value = module.ecr.repository_name
}

output "db_secret_arn" {
  description = "ARN of DB secret"
  value = module.secrets.rds_secret_arn
}