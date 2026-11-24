provider "aws" {
  region = var.region

  default_tags {
    tags = {
      owner       = var.owner
      environment = var.environment
      stack       = "elk-stack-2"
      managed_by  = "apex"
    }
  }
}
