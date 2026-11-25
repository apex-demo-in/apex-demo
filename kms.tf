data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Key policies are evaluated against the key's own ARN. Scoping to the keys of
  # this account and region keeps the statements constrained instead of "*".
  kms_key_arn_pattern = "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
}

# Customer-managed key for this stack. Reused by any resource in the stack that
# accepts a CMK; today that is the VPC flow log CloudWatch log group.
resource "aws_kms_key" "stack" {
  description             = "Customer-managed key for the ${var.name} stack"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.stack_key.json
}

resource "aws_kms_alias" "stack" {
  name          = "alias/${var.name}-stack"
  target_key_id = aws_kms_key.stack.key_id
}

data "aws_iam_policy_document" "stack_key" {
  statement {
    sid    = "AllowAccountAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = [local.kms_key_arn_pattern]
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]

    resources = [local.kms_key_arn_pattern]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }
}
