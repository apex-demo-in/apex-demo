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
  default     = ["us-west-2a", "us-west-2b"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets (ALB and Fargate outbound ECR pull)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository for the demo container image"
  type        = string
  default     = "podinfo"
}

variable "podinfo_image" {
  description = "Podinfo container image in the stack's ECR repository, pinned by digest"
  type        = string
  default     = "941377153949.dkr.ecr.us-west-2.amazonaws.com/podinfo@sha256:866131aab5da60d503184ef073a38260195166aa1fda1f7e0682ff572dd86bc9"
}
