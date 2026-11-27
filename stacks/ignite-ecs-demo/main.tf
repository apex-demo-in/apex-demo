data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  partition      = data.aws_partition.current.partition
  log_group_name = "/aws/ecs/${var.cluster_name}"
  log_group_arn  = "arn:${local.partition}:logs:${var.region}:${local.account_id}:log-group:${local.log_group_name}"

  common_tags = {
    owner       = var.owner
    environment = var.environment
  }
}

# One customer-managed KMS key for the stack, reused for ECS Exec and CloudWatch Logs.
resource "aws_kms_key" "this" {
  description             = "KMS key for the ${var.cluster_name} ECS cluster (ECS Exec and logs)"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = local.common_tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccountPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.region}.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = local.log_group_arn
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.cluster_name}-ecs"
  target_key_id = aws_kms_key.this.key_id
}

# ECS Fargate cluster from the approved registry module, with Container Insights enabled.
module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.12.0"

  cluster_name = var.cluster_name

  cluster_settings = [
    {
      name  = "containerInsights"
      value = "enabled"
    }
  ]

  cluster_configuration = {
    execute_command_configuration = {
      kms_key_id = aws_kms_key.this.arn
      logging    = "OVERRIDE"
      log_configuration = {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = local.log_group_name
      }
    }
  }

  # Log group for ECS Exec sessions, encrypted with the stack key.
  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = var.log_retention_days
  cloudwatch_log_group_kms_key_id        = aws_kms_key.this.arn

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
        base   = 1
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }

  # Cluster only: no services, task definitions or load balancer.
  services = {}

  tags = local.common_tags
}
