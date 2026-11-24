module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for idx, az in local.azs : cidrsubnet(var.vpc_cidr, 4, idx)]
  public_subnets  = []

  # No public ingress or egress path: the stack reaches AWS services over VPC endpoints.
  enable_nat_gateway   = false
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Private subnets must never hand out public IPs.
  map_public_ip_on_launch = false

  # Default security group is locked down with no ingress and no egress rules.
  manage_default_security_group  = true
  default_security_group_name    = "${local.name}-default-deny"
  default_security_group_ingress = []
  default_security_group_egress  = []

  # VPC flow logs to an encrypted CloudWatch log group.
  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_destination_type                       = "cloud-watch-logs"
  flow_log_traffic_type                           = "ALL"
  flow_log_max_aggregation_interval               = 60
  flow_log_cloudwatch_log_group_kms_key_id        = aws_kms_key.elk.arn
  flow_log_cloudwatch_log_group_retention_in_days = var.log_retention_days
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name}-vpc-endpoints"
  description = "Interface VPC endpoints for the ELK stack: accepts HTTPS from stack workloads only"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_logstash" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "HTTPS from Logstash tasks to interface VPC endpoints"

  referenced_security_group_id = aws_security_group.logstash.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# Gateway endpoint for S3, used for ECR image layers.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name = "${local.name}-s3"
  }
}

# Interface endpoints so private workloads reach ECR and CloudWatch Logs
# without any route to the internet.
resource "aws_vpc_endpoint" "interface" {
  for_each = toset(["ecr.api", "ecr.dkr", "logs"])

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${local.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${local.name}-${replace(each.key, ".", "-")}"
  }
}
