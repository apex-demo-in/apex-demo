# Network built from the approved registry VPC module. It creates the VPC,
# internet gateway, public subnet and route table, locks the default security
# group down to no rules, and ships flow logs to a KMS-encrypted log group.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = var.name
  cidr = var.vpc_cidr

  azs            = [data.aws_availability_zones.available.names[0]]
  public_subnets = [var.public_subnet_cidr]

  # The instance gets its public address from the Elastic IP, never from
  # subnet auto-assignment.
  map_public_ip_on_launch = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Default security group must exist with no ingress and no egress rules.
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_flow_log                                 = true
  flow_log_destination_type                       = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_cloudwatch_log_group_kms_key_id        = aws_kms_key.stack.arn
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_log_retention_days
  flow_log_max_aggregation_interval               = 60

  public_subnet_tags = {
    Name = "${var.name}-public"
  }
}
