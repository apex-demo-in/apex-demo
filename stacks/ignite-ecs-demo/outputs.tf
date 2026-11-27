output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = module.ecs_cluster.cluster_name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = module.ecs_cluster.cluster_arn
}

output "cluster_id" {
  description = "ID of the ECS cluster."
  value       = module.ecs_cluster.cluster_id
}

output "kms_key_arn" {
  description = "ARN of the stack's customer-managed KMS key."
  value       = aws_kms_key.this.arn
}

output "exec_log_group_name" {
  description = "CloudWatch log group used for ECS Exec sessions."
  value       = local.log_group_name
}
