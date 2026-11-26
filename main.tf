module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets

  create_igw         = false
  enable_nat_gateway = false

  manage_default_network_acl     = true
  manage_default_route_table     = true
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []
}
