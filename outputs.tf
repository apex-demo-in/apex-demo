output "bucket_id" {
  description = "Name of the public assets bucket."
  value       = module.public_bucket.s3_bucket_id
}

output "bucket_arn" {
  description = "ARN of the public assets bucket."
  value       = module.public_bucket.s3_bucket_arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the public assets bucket."
  value       = module.public_bucket.s3_bucket_bucket_regional_domain_name
}

output "log_bucket_id" {
  description = "Name of the private server access log bucket."
  value       = module.log_bucket.s3_bucket_id
}

output "kms_key_arn" {
  description = "ARN of the stack KMS key used for bucket encryption."
  value       = aws_kms_key.this.arn
}
