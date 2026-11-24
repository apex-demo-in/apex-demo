terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  domain_arn = "arn:aws:es:${local.region}:${local.account_id}:domain/${var.domain_name}"

  # Audit logs require fine-grained access control, which this domain enables.
  log_types = [
    "INDEX_SLOW_LOGS",
    "SEARCH_SLOW_LOGS",
    "ES_APPLICATION_LOGS",
    "AUDIT_LOGS",
  ]
}

# --- Logging ------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "this" {
  for_each = toset(local.log_types)

  name              = "/aws/opensearch/${var.domain_name}/${lower(each.value)}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.kms_key_arn

  tags = {
    Name = "${var.domain_name}-${lower(each.value)}"
  }
}

data "aws_iam_policy_document" "logs" {
  statement {
    sid    = "AllowOpenSearchLogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["es.amazonaws.com"]
    }

    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
    ]

    resources = [for lg in aws_cloudwatch_log_group.this : "${lg.arn}:*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.domain_arn]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "this" {
  policy_name     = "${var.domain_name}-log-delivery"
  policy_document = data.aws_iam_policy_document.logs.json
}

# --- Network ------------------------------------------------------------------

resource "aws_security_group" "this" {
  name_prefix = "${var.domain_name}-opensearch-"
  description = "Controls HTTPS access to the ${var.domain_name} OpenSearch domain"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.domain_name}-opensearch"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_client_security_groups" {
  for_each = toset(var.client_security_group_ids)

  security_group_id            = aws_security_group.this.id
  description                  = "HTTPS from an authorised ELK client security group"
  referenced_security_group_id = each.value
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "from_client_cidrs" {
  for_each = toset(var.client_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "HTTPS from an authorised ELK client network range"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# --- Domain -------------------------------------------------------------------

data "aws_iam_policy_document" "access" {
  statement {
    sid    = "AllowNamedRolesOverHttps"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.access_principal_arns
    }

    actions = [
      "es:ESHttpGet",
      "es:ESHttpPost",
      "es:ESHttpPut",
      "es:ESHttpDelete",
      "es:ESHttpHead",
    ]

    resources = ["${local.domain_arn}/*"]
  }
}

resource "aws_opensearch_domain" "this" {
  domain_name    = var.domain_name
  engine_version = var.engine_version

  cluster_config {
    instance_type  = var.data_instance_type
    instance_count = var.data_instance_count

    dedicated_master_enabled = true
    dedicated_master_type    = var.master_instance_type
    dedicated_master_count   = 3

    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = var.availability_zone_count
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = var.volume_size
    throughput  = 125
    iops        = 3000
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = var.tls_security_policy
  }

  # Fine-grained access control using the internal user database. IAM
  # principals in access_principal_arns must additionally be mapped to a role
  # in the OpenSearch security plugin before they can read or write.
  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    anonymous_auth_enabled         = false

    master_user_options {
      master_user_name     = var.master_user_name
      master_user_password = var.master_user_password
    }
  }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.this.id]
  }

  log_publishing_options {
    log_type                 = "INDEX_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.this["INDEX_SLOW_LOGS"].arn
    enabled                  = true
  }

  log_publishing_options {
    log_type                 = "SEARCH_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.this["SEARCH_SLOW_LOGS"].arn
    enabled                  = true
  }

  log_publishing_options {
    log_type                 = "ES_APPLICATION_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.this["ES_APPLICATION_LOGS"].arn
    enabled                  = true
  }

  log_publishing_options {
    log_type                 = "AUDIT_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.this["AUDIT_LOGS"].arn
    enabled                  = true
  }

  auto_tune_options {
    desired_state       = "ENABLED"
    rollback_on_disable = "NO_ROLLBACK"
  }

  software_update_options {
    auto_software_update_enabled = true
  }

  off_peak_window_options {
    enabled = true

    off_peak_window {
      window_start_time {
        hours   = 2
        minutes = 0
      }
    }
  }

  access_policies = data.aws_iam_policy_document.access.json

  tags = {
    Name = var.domain_name
  }

  depends_on = [aws_cloudwatch_log_resource_policy.this]
}
