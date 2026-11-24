output "opensearch_domain_arn" {
  description = "ARN of the OpenSearch domain."
  value       = aws_opensearch_domain.elk.arn
}

output "opensearch_endpoint" {
  description = "VPC endpoint hostname for the Elasticsearch API (HTTPS, reachable from inside the VPC only)."
  value       = aws_opensearch_domain.elk.endpoint
}

output "kibana_dashboards_endpoint" {
  description = "Kibana/OpenSearch Dashboards URL, reachable from inside the VPC only (VPN, bastion or private load balancer)."
  value       = "https://${aws_opensearch_domain.elk.dashboard_endpoint}"
}

output "opensearch_admin_role_arn" {
  description = "Role to assume (with MFA) for fine-grained admin access to Dashboards."
  value       = aws_iam_role.opensearch_admin.arn
}

output "logstash_image_repository_url" {
  description = "ECR repository to mirror the Logstash image into before deploying."
  value       = aws_ecr_repository.logstash.repository_url
}

output "logstash_service_name" {
  description = "Name of the Logstash ECS service."
  value       = aws_ecs_service.logstash.name
}

output "vpc_id" {
  description = "ID of the VPC hosting the ELK stack."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets hosting the OpenSearch ENIs and Logstash tasks."
  value       = module.vpc.private_subnets
}

output "kms_key_arn" {
  description = "ARN of the customer managed key used for encryption at rest across the stack."
  value       = aws_kms_key.elk.arn
}
