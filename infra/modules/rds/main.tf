resource "aws_db_subnet_group" "multiaz_rds" {
  name       = "multiaz_rds_subnet_group"
  subnet_ids = var.isolated_subnets_id

  tags = merge(var.tags, { Name = "database-subnet-group" }, { Environment = "Modules/rds" })
}

resource "aws_db_instance" "multiaz_rds" {
  identifier        = "postgres"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.multiaz_rds.name
  vpc_security_group_ids = [var.db_sg_group_id]

  publicly_accessible = false

  storage_type      = "gp3"
  storage_encrypted = true
  multi_az          = true

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  deletion_protection     = false #true in production
  skip_final_snapshot     = true  #false in production

  tags = merge(var.tags, { Name = "database-instance" }, { Environment = "Modules/rds" })

}

