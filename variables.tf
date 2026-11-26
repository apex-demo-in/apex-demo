variable "aws_region" {
  description = "AWS region to deploy VPC resources"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Deployment environment tag (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Team or individual owner tag for governance compliance"
  type        = string
  default     = "platform-team"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "minimal-sample-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones for the subnets"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}
