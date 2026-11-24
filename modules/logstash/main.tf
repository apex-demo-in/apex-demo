terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

data "aws_region" "current" {}

locals {
  name = "${var.name_prefix}-logstash"
}

# --- Image registry -----------------------------------------------------------

resource "aws_ecr_repository" "this" {
  name                 = "${var.name_prefix}/logstash"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = {
    Name = local.name
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the 30 most recent tagged images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = { type = "expire" }
      },
    ]
  })
}

# --- Logging -------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "task" {
  name              = "/aws/ecs/${local.name}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.kms_key_arn

  tags = {
    Name = local.name
  }
}

resource "aws_cloudwatch_log_group" "exec" {
  name              = "/aws/ecs/${var.name_prefix}-exec"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.kms_key_arn

  tags = {
    Name = "${var.name_prefix}-exec"
  }
}

# --- Cluster --------------------------------------------------------------------

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      kms_key_id = var.kms_key_arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.exec.name
      }
    }
  }

  tags = {
    Name = "${var.name_prefix}-cluster"
  }
}

# --- IAM --------------------------------------------------------------------------

data "aws_iam_policy_document" "task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  description        = "Pulls the Logstash image and writes task logs"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_extra" {
  statement {
    sid    = "DecryptLogAndImageEncryptionKey"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]

    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "execution_extra" {
  name   = "${local.name}-execution-kms"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_extra.json
}

resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  description        = "Identity Logstash uses to write documents into OpenSearch"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

data "aws_iam_policy_document" "task" {
  statement {
    sid    = "WriteToOpenSearch"
    effect = "Allow"

    actions = [
      "es:ESHttpGet",
      "es:ESHttpPost",
      "es:ESHttpPut",
      "es:ESHttpHead",
    ]

    resources = ["${var.opensearch_domain_arn}/*"]
  }

  statement {
    sid    = "ArchiveToS3"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload",
    ]

    resources = ["${var.archive_bucket_arn}/logstash/*"]
  }

  statement {
    sid    = "UseStackKey"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]

    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "${local.name}-task"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}

# --- Network -----------------------------------------------------------------------

resource "aws_security_group" "this" {
  name_prefix = "${local.name}-"
  description = "Controls Beats ingestion into Logstash and its egress to OpenSearch"
  vpc_id      = var.vpc_id

  tags = {
    Name = local.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "beats" {
  for_each = toset(var.beats_ingest_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "Beats log shipping from an authorised network range"
  cidr_ipv4         = each.value
  from_port         = 5044
  to_port           = 5044
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "opensearch" {
  security_group_id            = aws_security_group.this.id
  description                  = "HTTPS to the OpenSearch domain"
  referenced_security_group_id = var.opensearch_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "vpc_endpoints" {
  security_group_id            = aws_security_group.this.id
  description                  = "HTTPS to interface VPC endpoints for ECR, CloudWatch Logs and KMS"
  referenced_security_group_id = var.vpc_endpoint_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "s3_gateway" {
  security_group_id = aws_security_group.this.id
  description       = "HTTPS to S3 through the gateway endpoint, for ECR image layers and archives"
  prefix_list_id    = var.s3_prefix_list_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# --- Service discovery ------------------------------------------------------------

resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = var.service_namespace
  description = "Private DNS namespace for ELK stack services"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "this" {
  name        = "logstash"
  description = "Resolves to the running Logstash tasks for Beats clients"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# --- Task and service ----------------------------------------------------------------

resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  # The root filesystem is read-only, so every path Logstash writes to is an
  # explicit ephemeral volume.
  volume {
    name = "logstash-data"
  }

  volume {
    name = "logstash-logs"
  }

  volume {
    name = "logstash-tmp"
  }

  container_definitions = jsonencode([
    {
      name                   = "logstash"
      image                  = "${aws_ecr_repository.this.repository_url}:${var.image_tag}"
      essential              = true
      readonlyRootFilesystem = true
      user                   = "1000"

      portMappings = [
        {
          containerPort = 5044
          protocol      = "tcp"
        },
      ]

      mountPoints = [
        {
          sourceVolume  = "logstash-data"
          containerPath = "/usr/share/logstash/data"
          readOnly      = false
        },
        {
          sourceVolume  = "logstash-logs"
          containerPath = "/usr/share/logstash/logs"
          readOnly      = false
        },
        {
          sourceVolume  = "logstash-tmp"
          containerPath = "/tmp"
          readOnly      = false
        },
      ]

      environment = [
        {
          name  = "OPENSEARCH_HOSTS"
          value = "https://${var.opensearch_endpoint}:443"
        },
        {
          name  = "AWS_REGION"
          value = data.aws_region.current.name
        },
        {
          name  = "LS_JAVA_OPTS"
          value = "-Xms${floor(var.task_memory / 4)}m -Xmx${floor(var.task_memory / 2)}m"
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.task.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "logstash"
        }
      }
    },
  ])

  tags = {
    Name = local.name
  }
}

resource "aws_ecs_service" "this" {
  name             = local.name
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.this.arn
  desired_count    = var.desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.this.arn
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = {
    Name = local.name
  }
}
