variable "region" {
  description = "AWS region the stack deploys into."
  type        = string
  default     = "us-east-2"
}

variable "owner" {
  description = "Owner tag applied to every resource in this stack."
  type        = string
  default     = "platform-team"
}

variable "environment" {
  description = "Environment tag applied to every resource in this stack."
  type        = string
  default     = "demo"
}

variable "repository_name" {
  description = "Name of the ECR repository that holds the demo application image."
  type        = string
  default     = "demo-app"
}

variable "untagged_image_expiry_days" {
  description = "Number of days after which untagged images in the repository expire."
  type        = number
  default     = 14
}

variable "max_tagged_image_count" {
  description = "Maximum number of tagged images kept in the repository."
  type        = number
  default     = 30
}
