variable "podinfo_image" {
  description = "podinfo container image in the stack's ECR repository, pinned by digest"
  type        = string
  default     = "941377153949.dkr.ecr.us-west-2.amazonaws.com/podinfo@sha256:866131aab5da60d503184ef073a38260195166aa1fda1f7e0682ff572dd86bc9"
}

variable "podinfo_port" {
  description = "Port the podinfo container listens on"
  type        = string
  default     = "9898"
}

# Role App Runner assumes to pull the image from the private ECR repository
resource "aws_iam_role" "apprunner_ecr_access" {
  name        = "podinfo-apprunner-ecr-access"
  description = "Allows App Runner to pull the podinfo image from ECR"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_access" {
  role       = aws_iam_role.apprunner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

resource "aws_apprunner_service" "podinfo" {
  service_name = "podinfo-demo"

  source_configuration {
    auto_deployments_enabled = false

    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access.arn
    }

    image_repository {
      image_identifier      = var.podinfo_image
      image_repository_type = "ECR"

      image_configuration {
        port = var.podinfo_port
      }
    }
  }

  instance_configuration {
    cpu    = "256"
    memory = "512"
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/healthz"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }

  encryption_configuration {
    kms_key = aws_kms_key.main.arn
  }

  depends_on = [aws_iam_role_policy_attachment.apprunner_ecr_access]
}

output "podinfo_url" {
  description = "Public HTTPS URL of the podinfo demo"
  value       = "https://${aws_apprunner_service.podinfo.service_url}"
}
