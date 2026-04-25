variable "name" {
  description = "Name of the Environment"
  type        = string
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
}

variable "recovery_window_in_days" {
  description = "Number of days before secret is permanently deleted"
  type = number
  default = 0 # portfolio default - change to 30 for production
}