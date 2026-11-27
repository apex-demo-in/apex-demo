provider "aws" {
  region = var.region

  default_tags {
    tags = {
      owner       = var.owner
      environment = var.environment
      managed_by  = "apex"
      stack       = "ignite-ecs-demo"
    }
  }
}
