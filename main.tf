module "network" {
  source                               = "terraform-aws-modules/vpc/aws"
  version                              = "5.16.0"

  name                                 = var.name
  cidr                                 = var.cidr
  azs                                  = var.availability_zones
  private_subnets                      = var.private_subnets
  public_subnets                       = var.public_subnets
  enable_nat_gateway                   = true
  single_nat_gateway                   = true
  enable_dns_hostnames                 = true
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60
  manage_default_security_group        = true
  default_security_group_ingress       = []
  default_security_group_egress        = []
}
