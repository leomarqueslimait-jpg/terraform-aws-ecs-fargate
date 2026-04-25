variable "isolated_subnets_id" {
  description = "ID of the private subnets for database deployment"
  type        = list(string)
}

variable "instance_class" {
  description = "Instance class of database"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage size of Databse"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of database"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_sg_group_id" {
  description = "ID of isolated subnet from network module"
  type        = string
}


variable "tags" {
  type = map(string)
}