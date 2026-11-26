provider "aws" {
  region = var.region

  default_tags {
    tags = {
      owner       = var.owner
      environment = var.environment
      stack       = var.name
      managed_by  = "apex"
    }
  }
}
