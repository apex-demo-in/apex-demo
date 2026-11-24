provider "aws" {
  region = var.region

  default_tags {
    tags = {
      owner       = var.owner
      environment = var.environment
      stack       = "public-s3"
      managed_by  = "apex"
    }
  }
}
