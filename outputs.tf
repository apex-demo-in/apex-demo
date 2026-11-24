output "vpc_id" {
  description = "ID of the ELK VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets hosting OpenSearch and Logstash."
  value       = module.vpc.private_subnets
}

output "opensearch_endpoint" {
  description = "Elasticsearch API endpoint. Reachable from inside the VPC only."
  value       = module.opensearch.domain_endpoint
}

output "dashboards_endpoint" {
  description = "Kibana / OpenSearch Dashboards endpoint. Reachable from inside the VPC only."
  value       = module.opensearch.dashboards_endpoint
}

output "dashboards_master_user_name" {
  description = "Username of the Dashboards master user in the internal user database."
  value       = var.opensearch_master_user_name
}

output "dashboards_master_password_ssm_parameter" {
  description = "SSM SecureString parameter holding the Dashboards master password. Read it with: aws ssm get-parameter --with-decryption --name <this>"
  value       = aws_ssm_parameter.dashboards_master_password.name
}

output "domain_access_role_arn" {
  description = "IAM role permitted to call the domain API. Needs a role mapping in the OpenSearch security plugin before it can read or write."
  value       = aws_iam_role.dashboards_admin.arn
}

output "logstash_ingest_endpoint" {
  description = "DNS name Beats agents ship to on port 5044."
  value       = module.logstash.ingest_endpoint
}

output "logstash_repository_url" {
  description = "Push the Logstash image here before the service can start tasks."
  value       = module.logstash.repository_url
}

output "logstash_task_role_arn" {
  description = "Logstash task role. Needs a role mapping in the OpenSearch security plugin before it can index documents."
  value       = module.logstash.task_role_arn
}

output "archive_bucket_name" {
  description = "Archive bucket for snapshots and long-term log storage."
  value       = aws_s3_bucket.archive.id
}

output "archive_replica_bucket_name" {
  description = "Cross-region replica of the archive bucket."
  value       = aws_s3_bucket.archive_replica.id
}

output "snapshot_role_arn" {
  description = "Role to register as the OpenSearch snapshot repository role."
  value       = aws_iam_role.snapshot.arn
}

output "kms_key_arn" {
  description = "Stack KMS key protecting the ELK data at rest."
  value       = module.kms_primary.key_arn
}
