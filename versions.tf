terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Primary region: all ELK components live here.
provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# Replica region: holds the cross-region replica of the archive bucket so that
# S3 data survives the loss of a single region.
provider "aws" {
  alias  = "replica"
  region = var.replica_region

  default_tags {
    tags = local.common_tags
  }
}
