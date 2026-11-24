data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  log_bucket_name = "${var.bucket_name}-logs"
  kms_key_scope   = "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
}

# Stack KMS key. Scoped statements rather than a wildcard: account principals get
# key administration, the data plane gets encrypt/decrypt, and S3 log delivery
# gets just enough to write access logs.
data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "KeyAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
    ]

    resources = [local.kms_key_scope]
  }

  statement {
    sid    = "KeyUsage"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = [local.kms_key_scope]
  }

  statement {
    sid    = "AllowS3LogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]

    resources = [local.kms_key_scope]
  }
}

resource "aws_kms_key" "this" {
  description             = "Stack key for public-s3 bucket encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "this" {
  name          = "alias/public-s3-stack"
  target_key_id = aws_kms_key.this.key_id
}

# Private log bucket. Receives server access logs from the public bucket and
# from itself; locked down regardless of how the public bucket is configured.
module "log_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.2.2"

  bucket        = local.log_bucket_name
  force_destroy = false

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  attach_public_policy                  = true
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  attach_access_log_delivery_policy          = true
  access_log_delivery_policy_source_buckets  = ["arn:aws:s3:::${var.bucket_name}"]
  access_log_delivery_policy_source_accounts = [data.aws_caller_identity.current.account_id]

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.this.arn
      }
      bucket_key_enabled = true
    }
  }

  logging = {
    target_bucket = local.log_bucket_name
    target_prefix = "self/"
  }

  lifecycle_rule = [
    {
      id     = "expire-logs"
      status = "Enabled"

      abort_incomplete_multipart_upload_days = 7

      expiration = {
        days = var.log_retention_days
      }

      noncurrent_version_expiration = {
        noncurrent_days = 30
      }
    }
  ]
}

resource "aws_s3_bucket_notification" "log_bucket" {
  bucket      = module.log_bucket.s3_bucket_id
  eventbridge = true
}

# Public assets bucket, as requested: public-read ACL, all four public access
# blocks disabled, and a bucket policy granting s3:GetObject to everyone.
data "aws_iam_policy_document" "public_read" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/*"]
  }
}

module "public_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.2.2"

  bucket        = var.bucket_name
  force_destroy = false

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"
  acl                      = "public-read"

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  attach_public_policy = true
  attach_policy        = true
  policy               = data.aws_iam_policy_document.public_read.json

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.this.arn
      }
      bucket_key_enabled = true
    }
  }

  logging = {
    target_bucket = module.log_bucket.s3_bucket_id
    target_prefix = "access/"
  }

  lifecycle_rule = [
    {
      id     = "abort-incomplete-uploads"
      status = "Enabled"

      abort_incomplete_multipart_upload_days = 7

      noncurrent_version_expiration = {
        noncurrent_days = 90
      }
    }
  ]
}

resource "aws_s3_bucket_notification" "public_bucket" {
  bucket      = module.public_bucket.s3_bucket_id
  eventbridge = true
}
