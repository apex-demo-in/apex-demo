output "cluster_arn" {
  description = "ARN of the ECS cluster running Logstash."
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "Name of the Logstash ECS service."
  value       = aws_ecs_service.this.name
}

output "repository_url" {
  description = "ECR repository the Logstash image must be pushed to before tasks can start."
  value       = aws_ecr_repository.this.repository_url
}

output "security_group_id" {
  description = "Security group attached to the Logstash tasks."
  value       = aws_security_group.this.id
}

output "ingest_endpoint" {
  description = "DNS name Beats clients send logs to on port 5044."
  value       = "logstash.${var.service_namespace}"
}

output "task_role_arn" {
  description = "ARN of the Logstash task role."
  value       = aws_iam_role.task.arn
}
