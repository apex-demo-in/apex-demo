variable "region" {
  description = "AWS region to deploy the example network into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix applied to all network resources."
  type        = string
  default     = "apex-demo"
}

variable "owner" {
  description = "Owner tag applied to every resource via provider default tags."
  type        = string
  default     = "platform-team"
}

variable "environment" {
  description = "Environment tag applied to every resource via provider default tags."
  type        = string
  default     = "demo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Public and private subnets are carved out of it as /20s."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread the private subnets across."
  type        = number
  default     = 2
}

variable "public_subnet_count" {
  description = "Number of public subnets to create, starting from the first availability zone."
  type        = number
  default     = 1

  validation {
    condition     = var.public_subnet_count >= 1 && var.public_subnet_count <= var.az_count
    error_message = "public_subnet_count must be at least 1 and no greater than az_count."
  }
}

variable "flow_log_retention_days" {
  description = "Retention in days for the VPC flow log group."
  type        = number
  default     = 365
}
