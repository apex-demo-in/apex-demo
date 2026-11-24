data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# NOTE: this VPC has no flow logging. Delivery requires an IAM role and the
# stack's AWS connection denies iam:CreateRole, so it cannot be created here.
# Tracked by an approved scan exception for CKV2_AWS_11 (warn), which is
# intended to be withdrawn once the connection can create the delivery role.

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Private subnets exist in every AZ; public subnets only in the first
  # public_subnet_count AZs.
  public_azs = slice(local.azs, 0, var.public_subnet_count)

  # /20 subnets carved out of the VPC CIDR: public first, private offset by 8.
  public_subnets  = { for idx, az in local.public_azs : az => cidrsubnet(var.vpc_cidr, 4, idx) }
  private_subnets = { for idx, az in local.azs : az => cidrsubnet(var.vpc_cidr, 4, idx + 8) }

  # NAT gateways live in public subnets: one per public AZ, or a single shared one.
  nat_azs = var.enable_nat_gateway ? (var.single_nat_gateway ? slice(local.public_azs, 0, 1) : local.public_azs) : []
}

############################
# VPC
############################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

# The default security group must deny all traffic: no ingress and no egress rules.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-default-deny-all"
  }
}

############################
# Internet gateway (public tier: inbound/outbound path)
############################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-igw"
  }
}

############################
# Subnets
############################

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  # Instances must not get a public IP automatically; attach an ELB or EIP deliberately.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-public-${each.key}"
    tier = "public"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-private-${each.key}"
    tier = "private"
  }
}

############################
# NAT gateways: outbound-only internet path for the private subnets
############################

resource "aws_eip" "nat" {
  for_each = toset(local.nat_azs)

  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-eip-${each.key}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_azs)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "${var.name}-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.this]
}

############################
# Routing
############################

# One shared public route table: default route to the internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# One private route table per AZ, plus the S3 gateway endpoint. Its default
# route uses the NAT gateway in its own AZ when there is one, otherwise the NAT
# gateway in the first public AZ.
resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-private-rt-${each.key}"
  }
}

resource "aws_route" "private_nat" {
  for_each = var.enable_nat_gateway ? local.private_subnets : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[contains(local.nat_azs, each.key) ? each.key : local.nat_azs[0]].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

############################
# S3 gateway endpoint: S3 access that does not consume NAT data charges
############################

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]

  tags = {
    Name = "${var.name}-s3-endpoint"
  }
}
