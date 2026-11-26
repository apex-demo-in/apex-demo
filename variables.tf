variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
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

variable "azs" {
  description = "Availability zones configured on the stack"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository for the demo container image"
  type        = string
  default     = "podinfo"
}
