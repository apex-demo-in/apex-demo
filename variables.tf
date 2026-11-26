variable "region" {
  description = "AWS region to deploy the stack into."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Name prefix applied to all resources in this stack."
  type        = string
  default     = "ec2-stack"
}

variable "owner" {
  description = "Owner tag applied to every taggable resource via provider default_tags."
  type        = string
  default     = "apex-demo-in"
}

variable "environment" {
  description = "Environment tag applied to every taggable resource via provider default_tags."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet that hosts the instance."
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for the application instance."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Size in GiB of the encrypted root EBS volume."
  type        = number
  default     = 20
}

variable "flow_log_retention_days" {
  description = "Retention in days for the VPC flow log group. Must be at least 365."
  type        = number
  default     = 365

  validation {
    condition     = var.flow_log_retention_days >= 365
    error_message = "Flow log retention must be at least 365 days."
  }
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period in days before the stack KMS key is deleted."
  type        = number
  default     = 30
}
