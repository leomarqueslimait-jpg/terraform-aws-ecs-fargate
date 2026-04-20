variable "name" {
  description = "Name of the Environment"
  type = string
}

variable "tags" {
    description = "Tags for resources"
    type = map(string)
}