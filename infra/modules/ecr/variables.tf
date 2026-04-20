variable "name" {
    description = "Name of the ECR repository"
    type = string
}

variable "tags" {
  description = "Tags"
  type = map(string)
  default = {}
}