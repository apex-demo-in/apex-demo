output "ecr_repository_url" {
  description = "URL of the demo application ECR repository."
  value       = aws_ecr_repository.demo_app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the demo application ECR repository."
  value       = aws_ecr_repository.demo_app.arn
}

output "kms_key_arn" {
  description = "ARN of the stack customer-managed KMS key."
  value       = aws_kms_key.stack.arn
}
