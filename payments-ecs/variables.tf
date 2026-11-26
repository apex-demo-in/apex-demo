variable "region" {
  description = "AWS region to deploy the ECS cluster into."
  type        = string
  default     = "us-east-2"
}

variable "cluster_name" {
  description = "Name of the ECS cluster."
  type        = string
  default     = "payments"
}

variable "owner" {
  description = "Owner tag applied to every resource."
  type        = string
  default     = "payments-team"
}

variable "environment" {
  description = "Environment tag applied to every resource."
  type        = string
  default     = "dev"
}

variable "log_retention_days" {
  description = "Retention in days for the ECS Exec CloudWatch log group (minimum 365)."
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 365
    error_message = "log_retention_days must be at least 365."
  }
}
