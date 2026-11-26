data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 8)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = var.name
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Instances must opt in to a public IP explicitly; nothing gets one by default.
  map_public_ip_on_launch = false

  # Default security group is locked down with no ingress and no egress rules.
  manage_default_security_group  = true
  default_security_group_name    = "${var.name}-default-locked"
  default_security_group_ingress = []
  default_security_group_egress  = []

  # Flow logs are defined explicitly below so the log group uses the stack CMK.
  enable_flow_log = false
}
