provider "aws" {
  region = var.region

  default_tags {
    tags = {
      owner       = var.owner
      environment = var.environment
      managed_by  = "apex"
      stack       = "ecr-test"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}
