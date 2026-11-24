variable "region" {
  description = "AWS region the stack is deployed into."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Owning team or individual, applied as the owner tag on every resource."
  type        = string
  default     = "platform"
}

variable "environment" {
  description = "Deployment environment, applied as the environment tag on every resource."
  type        = string
  default     = "demo"
}

variable "bucket_name" {
  description = "Name of the public assets bucket."
  type        = string
  default     = "apex-demo-public-assets"
}

variable "log_retention_days" {
  description = "Number of days server access logs are retained in the log bucket."
  type        = number
  default     = 365
}
