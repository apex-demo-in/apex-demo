# The archive buckets are declared here in the root module rather than in a
# reusable child module so that each bucket and its replication configuration
# live in the same graph. Cross-region replication is configured in both
# directions, which keeps each bucket durable against the loss of one region.
# S3 does not re-replicate a replicated object, so this does not loop.

# --- Primary archive bucket ---------------------------------------------------

resource "aws_s3_bucket" "archive" {
  bucket        = local.archive_bucket_name
  force_destroy = false

  tags = {
    Name = local.archive_bucket_name
  }
}

resource "aws_s3_bucket_public_access_block" "archive" {
  bucket = aws_s3_bucket.archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "archive" {
  bucket = aws_s3_bucket.archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.kms_primary.key_arn
    }
    bucket_key_enabled = true
  }
}

# Server access logs land in this same bucket under a dedicated prefix. S3
# requires the log target to share the source bucket's region, and self-logging
# keeps that true without an extra bucket in every region.
resource "aws_s3_bucket_logging" "archive" {
  bucket = aws_s3_bucket.archive.id

  target_bucket = aws_s3_bucket.archive.id
  target_prefix = "s3-access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  bucket     = aws_s3_bucket.archive.id
  depends_on = [aws_s3_bucket_versioning.archive]

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition-current-versions"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {
      prefix = "s3-access-logs/"
    }

    expiration {
      days = var.log_retention_in_days
    }
  }
}

resource "aws_s3_bucket_notification" "archive" {
  bucket      = aws_s3_bucket.archive.id
  eventbridge = true
}

data "aws_iam_policy_document" "archive" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.archive.arn,
      "${aws_s3_bucket.archive.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyUnencryptedObjectUploads"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.archive.arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  # ACLs are disabled, so the logging service delivers through the bucket
  # policy instead.
  statement {
    sid    = "AllowServerAccessLogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.archive.arn}/s3-access-logs/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.archive.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "archive" {
  bucket     = aws_s3_bucket.archive.id
  policy     = data.aws_iam_policy_document.archive.json
  depends_on = [aws_s3_bucket_public_access_block.archive]
}

# --- Replica archive bucket ----------------------------------------------------

resource "aws_s3_bucket" "archive_replica" {
  provider = aws.replica

  bucket        = local.archive_replica_bucket_name
  force_destroy = false

  tags = {
    Name = local.archive_replica_bucket_name
  }
}

resource "aws_s3_bucket_public_access_block" "archive_replica" {
  provider = aws.replica

  bucket = aws_s3_bucket.archive_replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "archive_replica" {
  provider = aws.replica

  bucket = aws_s3_bucket.archive_replica.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "archive_replica" {
  provider = aws.replica

  bucket = aws_s3_bucket.archive_replica.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive_replica" {
  provider = aws.replica

  bucket = aws_s3_bucket.archive_replica.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.kms_replica.key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "archive_replica" {
  provider = aws.replica

  bucket = aws_s3_bucket.archive_replica.id

  target_bucket = aws_s3_bucket.archive_replica.id
  target_prefix = "s3-access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "archive_replica" {
  provider = aws.replica

  bucket     = aws_s3_bucket.archive_replica.id
  depends_on = [aws_s3_bucket_versioning.archive_replica]

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition-current-versions"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {
      prefix = "s3-access-logs/"
    }

    expiration {
      days = var.log_retention_in_days
    }
  }
}

resource "aws_s3_bucket_notification" "archive_replica" {
  provider = aws.replica

  bucket      = aws_s3_bucket.archive_replica.id
  eventbridge = true
}

data "aws_iam_policy_document" "archive_replica" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.archive_replica.arn,
      "${aws_s3_bucket.archive_replica.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyUnencryptedObjectUploads"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.archive_replica.arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  statement {
    sid    = "AllowServerAccessLogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.archive_replica.arn}/s3-access-logs/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.archive_replica.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "archive_replica" {
  provider = aws.replica

  bucket     = aws_s3_bucket.archive_replica.id
  policy     = data.aws_iam_policy_document.archive_replica.json
  depends_on = [aws_s3_bucket_public_access_block.archive_replica]
}

# --- Replication ------------------------------------------------------------------

data "aws_iam_policy_document" "replication_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication_primary" {
  name               = "${var.name_prefix}-replication-${var.region}"
  description        = "Replicates the ELK archive bucket to ${var.replica_region}"
  assume_role_policy = data.aws_iam_policy_document.replication_assume.json
}

data "aws_iam_policy_document" "replication_primary" {
  statement {
    sid    = "ReadSourceBucket"
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.archive.arn]
  }

  statement {
    sid    = "ReadSourceObjects"
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = ["${aws_s3_bucket.archive.arn}/*"]
  }

  statement {
    sid    = "WriteDestinationObjects"
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = ["${aws_s3_bucket.archive_replica.arn}/*"]
  }

  statement {
    sid       = "DecryptSourceObjects"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [module.kms_primary.key_arn]
  }

  statement {
    sid    = "EncryptDestinationObjects"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey",
    ]

    resources = [module.kms_replica.key_arn]
  }
}

resource "aws_iam_role_policy" "replication_primary" {
  name   = "${var.name_prefix}-replication-${var.region}"
  role   = aws_iam_role.replication_primary.id
  policy = data.aws_iam_policy_document.replication_primary.json
}

resource "aws_iam_role" "replication_secondary" {
  name               = "${var.name_prefix}-replication-${var.replica_region}"
  description        = "Replicates the ELK archive replica bucket back to ${var.region}"
  assume_role_policy = data.aws_iam_policy_document.replication_assume.json
}

data "aws_iam_policy_document" "replication_secondary" {
  statement {
    sid    = "ReadSourceBucket"
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.archive_replica.arn]
  }

  statement {
    sid    = "ReadSourceObjects"
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = ["${aws_s3_bucket.archive_replica.arn}/*"]
  }

  statement {
    sid    = "WriteDestinationObjects"
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = ["${aws_s3_bucket.archive.arn}/*"]
  }

  statement {
    sid       = "DecryptSourceObjects"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [module.kms_replica.key_arn]
  }

  statement {
    sid    = "EncryptDestinationObjects"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey",
    ]

    resources = [module.kms_primary.key_arn]
  }
}

resource "aws_iam_role_policy" "replication_secondary" {
  name   = "${var.name_prefix}-replication-${var.replica_region}"
  role   = aws_iam_role.replication_secondary.id
  policy = data.aws_iam_policy_document.replication_secondary.json
}

resource "aws_s3_bucket_replication_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id
  role   = aws_iam_role.replication_primary.arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = aws_s3_bucket.archive_replica.arn
      storage_class = "STANDARD"

      encryption_configuration {
        replica_kms_key_id = module.kms_replica.key_arn
      }
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.archive,
    aws_s3_bucket_versioning.archive_replica,
  ]
}

resource "aws_s3_bucket_replication_configuration" "archive_replica" {
  provider = aws.replica

  bucket = aws_s3_bucket.archive_replica.id
  role   = aws_iam_role.replication_secondary.arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = aws_s3_bucket.archive.arn
      storage_class = "STANDARD"

      encryption_configuration {
        replica_kms_key_id = module.kms_primary.key_arn
      }
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.archive,
    aws_s3_bucket_versioning.archive_replica,
  ]
}
