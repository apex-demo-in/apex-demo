# Network (VPC): generated from an Apex stack template.
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.79"
    }
  }
}

provider "aws" {
  region = var.region
}
