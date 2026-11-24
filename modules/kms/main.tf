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

  # Account administrators keep full control of the key so it can never be
  # orphaned; every other principal gets only the operations it needs.
  root_statement = [{
    Sid       = "EnableAccountAdministration"
    Effect    = "Allow"
    Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
    Action    = "kms:*"
    Resource  = "*"
  }]

  # CloudWatch Logs encrypts log groups with this key. The encryption context
  # condition stops the service being used as a confused deputy for log groups
  # in other accounts.
  logs_statement = [{
    Sid       = "AllowCloudWatchLogs"
    Effect    = "Allow"
    Principal = { Service = "logs.${local.region}.amazonaws.com" }
    Action = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    Resource = "*"
    Condition = {
      ArnLike = {
        "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${local.region}:${local.account_id}:log-group:*"
      }
    }
  }]

  service_statement = length(var.service_principals) == 0 ? [] : [{
    Sid       = "AllowStackServices"
    Effect    = "Allow"
    Principal = { Service = var.service_principals }
    Action = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
    ]
    Resource = "*"
    Condition = {
      StringEquals = {
        "kms:CallerAccount" = local.account_id
      }
    }
  }]
}

resource "aws_kms_key" "this" {
  description             = var.description
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_in_days
  multi_region            = false

  policy = jsonencode({
    Version   = "2012-10-17"
    Id        = var.name
    Statement = concat(local.root_statement, local.logs_statement, local.service_statement)
  })

  tags = {
    Name = var.name
  }
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}
