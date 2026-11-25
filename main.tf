data "aws_availability_zones" "available" {
  state = "available"
}

# Simple VPC with two private subnets, built from the approved registry module.
# VPC flow logging is intentionally not enabled on this stack.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = var.name
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = var.private_subnet_cidrs

  # No public subnets, NAT gateways or internet gateway: nothing in this VPC is
  # internet-reachable and no instance receives a public IP.
  map_public_ip_on_launch = false
  enable_nat_gateway      = false
  enable_dns_hostnames    = true
  enable_dns_support      = true

  # Default security group is locked down with no ingress or egress rules.
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []
}
