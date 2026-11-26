data "aws_caller_identity" "current" {}

resource "aws_kms_key" "main" {
  description             = "KMS key for ECR repository encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  create_igw              = true
  enable_nat_gateway      = false
  map_public_ip_on_launch = false

  manage_default_network_acl     = true
  manage_default_route_table     = true
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []
}

module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "2.3.1"

  repository_name                 = var.ecr_repository_name
  repository_image_tag_mutability = "IMMUTABLE"
  repository_image_scan_on_push   = true
  repository_encryption_type      = "KMS"
  repository_kms_key              = aws_kms_key.main.arn
  attach_repository_policy        = false
  create_repository_policy        = false

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.12.0"

  name                       = "podinfo-demo-alb"
  vpc_id                     = module.vpc.vpc_id
  subnets                    = module.vpc.public_subnets
  enable_deletion_protection = false

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "Allow HTTP traffic from the internet"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = var.vpc_cidr
      description = "Allow outbound traffic to VPC targets"
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "podinfo"
      }
    }
  }

  target_groups = {
    podinfo = {
      name_prefix       = "pod-"
      protocol          = "HTTP"
      port              = 9898
      target_type       = "ip"
      create_attachment = false

      health_check = {
        enabled             = true
        interval            = 15
        path                = "/healthz"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
        protocol            = "HTTP"
        matcher             = "200"
      }
    }
  }
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.12.0"

  cluster_name                = "podinfo-demo-cluster"
  create_cloudwatch_log_group = false

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    podinfo = {
      cpu                = 256
      memory             = 512
      assign_public_ip   = true
      enable_autoscaling = false

      task_exec_iam_statements = [
        {
          sid       = "AllowKMSDecryptForECR"
          actions   = ["kms:Decrypt"]
          resources = [aws_kms_key.main.arn]
        }
      ]

      container_definitions = {
        podinfo = {
          cpu                       = 256
          memory                    = 512
          essential                 = true
          image                     = var.podinfo_image
          readonly_root_filesystem  = false
          enable_cloudwatch_logging = false

          port_mappings = [
            {
              name          = "podinfo"
              containerPort = 9898
              hostPort      = 9898
              protocol      = "tcp"
            }
          ]
        }
      }

      load_balancer = {
        service = {
          target_group_arn = module.alb.target_groups["podinfo"].arn
          container_name   = "podinfo"
          container_port   = 9898
        }
      }

      subnet_ids = module.vpc.public_subnets

      security_group_rules = {
        alb_ingress_9898 = {
          type                     = "ingress"
          from_port                = 9898
          to_port                  = 9898
          protocol                 = "tcp"
          description              = "Allow traffic from ALB on port 9898"
          source_security_group_id = module.alb.security_group_id
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
          description = "Allow outbound ECR and AWS API calls"
        }
      }
    }
  }
}
