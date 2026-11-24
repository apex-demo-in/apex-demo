resource "aws_ecr_repository" "logstash" {
  name                 = "${local.name}/logstash"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.elk.arn
  }
}

resource "aws_ecr_lifecycle_policy" "logstash" {
  repository = aws_ecr_repository.logstash.name

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
        action = {
          type = "expire"
        }
      },
    ]
  })
}

resource "aws_security_group" "logstash" {
  name        = "${local.name}-logstash"
  description = "Logstash Fargate tasks: accepts Beats traffic from inside the VPC, egress to OpenSearch and VPC endpoints"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "logstash_beats" {
  security_group_id = aws_security_group.logstash.id
  description       = "Beats input from shippers inside the VPC"

  cidr_ipv4   = var.vpc_cidr
  from_port   = var.beats_port
  to_port     = var.beats_port
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "logstash_to_opensearch" {
  security_group_id = aws_security_group.logstash.id
  description       = "HTTPS to the OpenSearch domain"

  referenced_security_group_id = aws_security_group.opensearch.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "logstash_to_endpoints" {
  security_group_id = aws_security_group.logstash.id
  description       = "HTTPS to interface VPC endpoints for ECR and CloudWatch Logs"

  referenced_security_group_id = aws_security_group.vpc_endpoints.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "logstash_to_s3" {
  security_group_id = aws_security_group.logstash.id
  description       = "HTTPS to S3 via the gateway endpoint for ECR image layers"

  prefix_list_id = aws_vpc_endpoint.s3.prefix_list_id
  from_port      = 443
  to_port        = 443
  ip_protocol    = "tcp"
}

resource "aws_cloudwatch_log_group" "logstash" {
  name              = "/aws/ecs/${local.name}-logstash"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.elk.arn
}

resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/aws/ecs/${local.name}-exec"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.elk.arn
}

resource "aws_iam_role" "logstash_execution" {
  name        = "${local.name}-logstash-execution"
  description = "ECS task execution role for Logstash: pulls the image and writes container logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "logstash_execution" {
  role       = aws_iam_role.logstash_execution.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "logstash_execution_kms" {
  name = "${local.name}-logstash-execution-kms"
  role = aws_iam_role.logstash_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = [aws_kms_key.elk.arn]
      },
    ]
  })
}

resource "aws_iam_role" "logstash_task" {
  name        = "${local.name}-logstash-task"
  description = "Application role for Logstash tasks: writes documents to the OpenSearch domain"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "logstash_task" {
  name = "${local.name}-logstash-task"
  role = aws_iam_role.logstash_task.id

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
        ]
        Resource = ["${local.domain_arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = ["${aws_cloudwatch_log_group.logstash.arn}:*"]
      },
    ]
  })
}

resource "aws_ecs_cluster" "logstash" {
  name = "${local.name}-logstash"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.elk.arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "logstash" {
  cluster_name       = aws_ecs_cluster.logstash.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

resource "aws_ecs_task_definition" "logstash" {
  family                   = "${local.name}-logstash"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.logstash_cpu
  memory                   = var.logstash_memory
  execution_role_arn       = aws_iam_role.logstash_execution.arn
  task_role_arn            = aws_iam_role.logstash_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  volume {
    name = "logstash-data"
  }

  volume {
    name = "logstash-tmp"
  }

  container_definitions = jsonencode([
    {
      name                   = "logstash"
      image                  = "${aws_ecr_repository.logstash.repository_url}:${var.logstash_image_tag}"
      essential              = true
      readonlyRootFilesystem = true
      privileged             = false
      user                   = "1000:1000"

      portMappings = [
        {
          containerPort = var.beats_port
          protocol      = "tcp"
        },
      ]

      environment = [
        {
          name  = "OPENSEARCH_HOSTS"
          value = "https://${aws_opensearch_domain.elk.endpoint}:443"
        },
        {
          name  = "AWS_REGION"
          value = var.region
        },
        {
          name  = "LS_JAVA_OPTS"
          value = "-Xms1g -Xmx1g"
        },
      ]

      mountPoints = [
        {
          sourceVolume  = "logstash-data"
          containerPath = "/usr/share/logstash/data"
          readOnly      = false
        },
        {
          sourceVolume  = "logstash-tmp"
          containerPath = "/tmp"
          readOnly      = false
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.logstash.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "logstash"
        }
      }

      linuxParameters = {
        initProcessEnabled = true
      }
    },
  ])
}

resource "aws_ecs_service" "logstash" {
  name             = "${local.name}-logstash"
  cluster          = aws_ecs_cluster.logstash.id
  task_definition  = aws_ecs_task_definition.logstash.arn
  desired_count    = var.logstash_desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.logstash.id]
    assign_public_ip = false
  }

  depends_on = [aws_ecs_cluster_capacity_providers.logstash]
}
