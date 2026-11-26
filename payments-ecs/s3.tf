variable "assets_bucket_name" {
  description = "Name of the S3 bucket for static assets (must be globally unique)."
  type        = string
  default     = "payments-static-assets-941377153949-use2"
}

# Static assets bucket with public read access, as requested.
module "static_assets" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.2.2"

  bucket = var.assets_bucket_name

  # Public read: allow anyone to load the assets.
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:${local.partition}:s3:::${var.assets_bucket_name}/*"
      }
    ]
  })

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

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

  lifecycle_rule = [
    {
      id      = "expire-noncurrent-versions"
      enabled = true
      noncurrent_version_expiration = {
        days = 90
      }
      abort_incomplete_multipart_upload_days = 7
    }
  ]

  tags = local.common_tags
}

output "static_assets_bucket_name" {
  description = "Name of the static assets bucket."
  value       = module.static_assets.s3_bucket_id
}

output "static_assets_bucket_domain" {
  description = "Regional domain name of the static assets bucket."
  value       = module.static_assets.s3_bucket_bucket_regional_domain_name
}
