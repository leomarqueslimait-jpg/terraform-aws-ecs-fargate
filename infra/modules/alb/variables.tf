variable "alb_sg_ids" {
  description = "ALB security group ID"
  type        = string
}

variable "public_subnets_ids" {
  description = "Public subnets from Network module"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID from modules/networking"
  type        = string
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}