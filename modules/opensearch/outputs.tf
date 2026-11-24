output "domain_arn" {
  description = "ARN of the OpenSearch domain."
  value       = aws_opensearch_domain.this.arn
}

output "domain_endpoint" {
  description = "VPC endpoint of the OpenSearch domain, used by Logstash and Beats clients."
  value       = aws_opensearch_domain.this.endpoint
}

output "dashboards_endpoint" {
  description = "OpenSearch Dashboards (Kibana) endpoint. Reachable from inside the VPC only."
  value       = aws_opensearch_domain.this.dashboard_endpoint
}

output "security_group_id" {
  description = "Security group protecting the domain."
  value       = aws_security_group.this.id
}
