variable "vpc_cidr" {
  type        = string
  description = "VPC cidr block"
  default     = "10.1.0.0/16"
}

variable "name" {
  type        = string
  description = "Name of the project to name instances"
}

variable "private_subnets_cidr" {
  type        = list(string)
  description = "CIDR of private subnets"

}

variable "public_subnets_cidr" {
  type        = list(string)
  description = "CIDR of public subnets"
}

variable "isolated_subnets_cidr" {
  type        = list(string)
  description = "CIDR of siolated subnets"
}

variable "azs" {
  type        = list(string)
  description = "Availability zones for subnets"
}