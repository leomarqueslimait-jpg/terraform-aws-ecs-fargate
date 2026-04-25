variable "private_subnets_id" {
  description = "ID of private subnets"
  type        = list(string)
}

variable "ecs_sg_id" {
  description = "ID of ECS security_group"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of load balancer target group"
  type        = string
}

variable "container_image" {
  description = "ECS image of container"
  type        = string
}

variable "secrets_arn" {
  description = "ARN of secrets stored in Secrets Manager"
  type        = string
}

variable "db_endpoint" {
  description = "RDS Endpoint of database module"
  type        = string
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}