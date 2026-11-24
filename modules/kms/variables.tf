variable "name" {
  description = "Key name, used for the alias and the Name tag."
  type        = string
}

variable "description" {
  description = "Human-readable description of what the key protects."
  type        = string
}

variable "deletion_window_in_days" {
  description = "Waiting period before a scheduled key deletion takes effect."
  type        = number
  default     = 30
}

variable "service_principals" {
  description = "AWS service principals granted use of the key, for example es.amazonaws.com."
  type        = list(string)
  default     = []
}
