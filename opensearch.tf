resource "aws_security_group" "opensearch" {
  name        = "${local.name}-opensearch"
  description = "OpenSearch domain ENIs: accepts HTTPS from Logstash tasks within the VPC only"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "opensearch_from_logstash" {
  security_group_id = aws_security_group.opensearch.id
  description       = "HTTPS from Logstash tasks to the OpenSearch domain"

  referenced_security_group_id = aws_security_group.logstash.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_cloudwatch_log_group" "opensearch" {
  for_each = toset(["index-slow", "search-slow", "application", "audit"])

  name              = "/aws/opensearch/${var.domain_name}/${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.elk.arn
}

resource "aws_cloudwatch_log_resource_policy" "opensearch" {
  policy_name = "${local.name}-opensearch-logs"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowOpenSearchServiceToWriteLogs"
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Action = [
          "logs:PutLogEvents",
          "logs:PutLogEventsBatch",
          "logs:CreateLogStream",
        ]
        Resource = [for group in aws_cloudwatch_log_group.opensearch : "${group.arn}:*"]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
          ArnLike = {
            "aws:SourceArn" = local.domain_arn
          }
        }
      },
    ]
  })
}

# Fine-grained access control master role. Human operators assume this role with MFA
# to administer Kibana/Dashboards; no IAM users or access keys are created.
resource "aws_iam_role" "opensearch_admin" {
  name        = "${local.name}-opensearch-admin"
  description = "Fine-grained access control master role for the ELK OpenSearch domain"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:${local.partition}:iam::${local.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "opensearch_admin" {
  name = "${local.name}-opensearch-admin"
  role = aws_iam_role.opensearch_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpHead",
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpPatch",
          "es:ESHttpDelete",
        ]
        Resource = ["${local.domain_arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "es:DescribeDomain",
          "es:DescribeDomainConfig",
        ]
        Resource = [local.domain_arn]
      },
    ]
  })
}

resource "aws_opensearch_domain" "elk" {
  domain_name    = var.domain_name
  engine_version = var.engine_version

  cluster_config {
    instance_type          = var.data_instance_type
    instance_count         = var.data_instance_count
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = var.az_count
    }

    dedicated_master_enabled = true
    dedicated_master_type    = var.master_instance_type
    dedicated_master_count   = var.master_instance_count
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = var.data_volume_size
    throughput  = 125
    iops        = 3000
  }

  # VPC-only domain: no public endpoint.
  vpc_options {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.opensearch.id]
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = aws_kms_key.elk.arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = false
    anonymous_auth_enabled         = false

    master_user_options {
      master_user_arn = aws_iam_role.opensearch_admin.arn
    }
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
    "indices.fielddata.cache.size"           = "20"
  }

  log_publishing_options {
    log_type                 = "INDEX_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch["index-slow"].arn
    enabled                  = true
  }

  log_publishing_options {
    log_type                 = "SEARCH_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch["search-slow"].arn
    enabled                  = true
  }

  log_publishing_options {
    log_type                 = "ES_APPLICATION_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch["application"].arn
    enabled                  = true
  }

  log_publishing_options {
    log_type                 = "AUDIT_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch["audit"].arn
    enabled                  = true
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

  auto_tune_options {
    desired_state       = "ENABLED"
    rollback_on_disable = "NO_ROLLBACK"
    use_off_peak_window = true
  }

  software_update_options {
    auto_software_update_enabled = true
  }

  # Access is restricted to the stack roles; fine-grained access control applies on top.
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowStackRolesOnly"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.opensearch_admin.arn,
            aws_iam_role.logstash_task.arn,
          ]
        }
        Action   = "es:ESHttp*"
        Resource = "${local.domain_arn}/*"
      },
    ]
  })

  depends_on = [aws_cloudwatch_log_resource_policy.opensearch]
}
