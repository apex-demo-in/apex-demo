data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# The S3 gateway endpoint prefix list is the egress destination Logstash needs
# to pull ECR image layers without a NAT gateway.
data "aws_ec2_managed_prefix_list" "s3" {
  name = "com.amazonaws.${var.region}.s3"
}

locals {
  account_id = data.aws_caller_identity.current.account_id

  common_tags = {
    owner       = var.owner
    environment = var.environment
    stack       = "elk"
    managed_by  = "apex"
  }

  azs             = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]

  domain_name = "${var.name_prefix}-logs"

  # Built as strings rather than references so the OpenSearch access policy does
  # not create a dependency cycle with the Logstash module that consumes it.
  opensearch_domain_arn  = "arn:aws:es:${var.region}:${local.account_id}:domain/${local.domain_name}"
  logstash_task_role_arn = "arn:aws:iam::${local.account_id}:role/${var.name_prefix}-logstash-task"

  dashboards_admin_principals = length(var.dashboards_admin_principal_arns) > 0 ? var.dashboards_admin_principal_arns : ["arn:aws:iam::${local.account_id}:root"]

  opensearch_client_cidrs  = length(var.opensearch_client_cidr_blocks) > 0 ? var.opensearch_client_cidr_blocks : [var.vpc_cidr]
  beats_ingest_cidr_blocks = length(var.beats_ingest_cidr_blocks) > 0 ? var.beats_ingest_cidr_blocks : [var.vpc_cidr]

  archive_bucket_name         = "${var.name_prefix}-archive-${local.account_id}-${var.region}"
  archive_replica_bucket_name = "${var.name_prefix}-archive-${local.account_id}-${var.replica_region}"

  # Private connectivity to the AWS services the stack depends on, so no NAT
  # gateway or internet route is required.
  interface_endpoints = {
    ecr_api = "com.amazonaws.${var.region}.ecr.api"
    ecr_dkr = "com.amazonaws.${var.region}.ecr.dkr"
    logs    = "com.amazonaws.${var.region}.logs"
    kms     = "com.amazonaws.${var.region}.kms"
  }
}

# --- Encryption ----------------------------------------------------------------

module "kms_primary" {
  source = "./modules/kms"

  name                    = "${var.name_prefix}-stack"
  description             = "Stack key for the ELK stack in ${var.region}"
  deletion_window_in_days = var.kms_deletion_window_in_days

  service_principals = [
    "es.amazonaws.com",
    "delivery.logs.amazonaws.com",
    "ecr.amazonaws.com",
    "s3.amazonaws.com",
  ]
}

module "kms_replica" {
  source = "./modules/kms"

  providers = {
    aws = aws.replica
  }

  name                    = "${var.name_prefix}-stack-replica"
  description             = "Stack key for the ELK archive replica in ${var.replica_region}"
  deletion_window_in_days = var.kms_deletion_window_in_days

  service_principals = [
    "s3.amazonaws.com",
  ]
}

# --- Network ---------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = var.name_prefix
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets

  # No public subnets, no internet gateway and no NAT: every dependency is
  # reached through the VPC endpoints below.
  enable_nat_gateway      = false
  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = false

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_flow_log                                 = true
  flow_log_traffic_type                           = "ALL"
  flow_log_max_aggregation_interval               = 60
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_cloudwatch_log_group_kms_key_id        = module.kms_primary.key_arn
  flow_log_cloudwatch_log_group_retention_in_days = var.log_retention_in_days

  tags = local.common_tags
}

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.name_prefix}-vpce-"
  description = "Controls HTTPS access from the VPC to the interface VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.name_prefix}-vpce"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "HTTPS from inside the ELK VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = module.vpc.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.name_prefix}-${each.key}"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name = "${var.name_prefix}-s3"
  }
}

# --- Access roles -------------------------------------------------------------------

data "aws_iam_policy_document" "dashboards_admin_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.dashboards_admin_principals
    }
  }
}

# IAM role permitted to call the domain API. Fine-grained access control uses
# the internal user database, so this role is not the master user: it must be
# mapped to an OpenSearch security role before it can read or write.
resource "aws_iam_role" "dashboards_admin" {
  name               = "${var.name_prefix}-dashboards-admin"
  description        = "OpenSearch Dashboards administrator for the ELK stack"
  assume_role_policy = data.aws_iam_policy_document.dashboards_admin_assume.json
}

data "aws_iam_policy_document" "dashboards_admin" {
  statement {
    sid    = "AdministerDomain"
    effect = "Allow"

    actions = [
      "es:ESHttpGet",
      "es:ESHttpPost",
      "es:ESHttpPut",
      "es:ESHttpDelete",
      "es:ESHttpHead",
      "es:ESHttpPatch",
    ]

    resources = ["${local.opensearch_domain_arn}/*"]
  }
}

resource "aws_iam_role_policy" "dashboards_admin" {
  name   = "${var.name_prefix}-dashboards-admin"
  role   = aws_iam_role.dashboards_admin.id
  policy = data.aws_iam_policy_document.dashboards_admin.json
}

data "aws_iam_policy_document" "snapshot_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["es.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "snapshot" {
  name               = "${var.name_prefix}-snapshot"
  description        = "Lets OpenSearch write manual index snapshots to the archive bucket"
  assume_role_policy = data.aws_iam_policy_document.snapshot_assume.json
}

data "aws_iam_policy_document" "snapshot" {
  statement {
    sid       = "ListArchiveBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.archive.arn]
  }

  statement {
    sid    = "ManageSnapshotObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]

    resources = ["${aws_s3_bucket.archive.arn}/snapshots/*"]
  }

  statement {
    sid    = "UseStackKey"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]

    resources = [module.kms_primary.key_arn]
  }
}

resource "aws_iam_role_policy" "snapshot" {
  name   = "${var.name_prefix}-snapshot"
  role   = aws_iam_role.snapshot.id
  policy = data.aws_iam_policy_document.snapshot.json
}

# --- Elasticsearch and Kibana ----------------------------------------------------------

module "opensearch" {
  source = "./modules/opensearch"

  domain_name    = local.domain_name
  engine_version = var.opensearch_engine_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  kms_key_arn = module.kms_primary.key_arn

  master_user_name     = var.opensearch_master_user_name
  master_user_password = random_password.dashboards_master.result

  access_principal_arns = [
    aws_iam_role.dashboards_admin.arn,
    local.logstash_task_role_arn,
  ]

  client_cidr_blocks = local.opensearch_client_cidrs

  data_instance_type      = var.opensearch_data_instance_type
  data_instance_count     = var.opensearch_data_instance_count
  master_instance_type    = var.opensearch_master_instance_type
  volume_size             = var.opensearch_volume_size
  availability_zone_count = var.az_count

  log_retention_in_days = var.log_retention_in_days
}

# --- Logstash -------------------------------------------------------------------------

module "logstash" {
  source = "./modules/logstash"

  name_prefix = var.name_prefix

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  kms_key_arn = module.kms_primary.key_arn

  opensearch_endpoint          = module.opensearch.domain_endpoint
  opensearch_domain_arn        = module.opensearch.domain_arn
  opensearch_security_group_id = module.opensearch.security_group_id

  vpc_endpoint_security_group_id = aws_security_group.vpc_endpoints.id
  s3_prefix_list_id              = data.aws_ec2_managed_prefix_list.s3.id

  archive_bucket_arn = aws_s3_bucket.archive.arn

  image_tag     = var.logstash_image_tag
  task_cpu      = var.logstash_task_cpu
  task_memory   = var.logstash_task_memory
  desired_count = var.logstash_desired_count

  beats_ingest_cidr_blocks = local.beats_ingest_cidr_blocks
  service_namespace        = "${var.name_prefix}.internal"

  log_retention_in_days = var.log_retention_in_days
}
