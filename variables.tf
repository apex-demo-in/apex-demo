variable "region" {
  description = "AWS region the VPC is created in."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Name prefix applied to the VPC and its resources."
  type        = string
  default     = "network-vpc"
}

variable "owner" {
  description = "Owning team, applied to every resource through provider default tags."
  type        = string
  default     = "platform"
}

variable "environment" {
  description = "Deployment environment, applied to every resource through provider default tags."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway instead of one per availability zone. Cheaper, but not zone redundant."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention in days for the VPC flow log group. Must be at least 365 to satisfy platform policy."
  type        = number
  default     = 365

  validation {
    condition     = var.flow_log_retention_days >= 365
    error_message = "flow_log_retention_days must be at least 365."
  }
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period before the stack KMS key is deleted."
  type        = number
  default     = 30
}
