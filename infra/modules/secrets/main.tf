resource "random_password" "db" {
  length = 16
  special = true
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = random_password.db.result

}

resource "aws_secretsmanager_secret" "db" {
  description = "Databse password container"
  name = var.name
  tags = merge(var.tags, { Name = "db_password"})

}