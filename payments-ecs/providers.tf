provider "aws" {
  region = var.region

  default_tags {
    tags = {
      owner       = var.owner
      environment = var.environment
      team        = "payments"
      managed_by  = "apex"
      stack       = "payments-ecs"
    }
  }
}
