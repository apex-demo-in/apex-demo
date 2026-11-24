data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Private subnets exist in every AZ; public subnets only in the first
  # public_subnet_count AZs.
  public_azs = slice(local.azs, 0, var.public_subnet_count)

  # /20 subnets carved out of the VPC CIDR: public first, private offset by 8.
  public_subnets  = { for idx, az in local.public_azs : az => cidrsubnet(var.vpc_cidr, 4, idx) }
  private_subnets = { for idx, az in local.azs : az => cidrsubnet(var.vpc_cidr, 4, idx + 8) }
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
# Internet gateway (public tier: for load balancers and bastion-free ingress)
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

# Private subnets have no route to the internet at all: no NAT gateway, so no
# outbound egress. AWS services are reached over VPC endpoints instead.
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

# One private route table per AZ. It carries only local VPC routes plus the S3
# gateway endpoint; there is deliberately no 0.0.0.0/0 route.
resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-private-rt-${each.key}"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

############################
# S3 gateway endpoint: private subnets reach S3 without any egress path
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
