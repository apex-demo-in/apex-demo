variable "region" {
  description = "AWS region to deploy the VPC into."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Name prefix applied to the VPC and its subordinate resources."
  type        = string
  default     = "test"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the two private subnets, one per availability zone."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly two private subnet CIDR blocks must be provided."
  }
}

variable "owner" {
  description = "Owner tag applied to every taggable resource."
  type        = string
  default     = "platform-team"
}

variable "environment" {
  description = "Environment tag applied to every taggable resource."
  type        = string
  default     = "dev"
}
