output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet hosting the instance."
  value       = module.vpc.public_subnets[0]
}

output "instance_id" {
  description = "ID of the application EC2 instance."
  value       = aws_instance.app.id
}

output "instance_security_group_id" {
  description = "ID of the security group attached to the application instance."
  value       = aws_security_group.instance.id
}

output "instance_role_arn" {
  description = "ARN of the IAM role attached to the application instance."
  value       = aws_iam_role.instance.arn
}

output "elastic_ip" {
  description = "Public Elastic IP address associated with the application instance."
  value       = aws_eip.app.public_ip
}

output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used by this stack."
  value       = aws_kms_key.stack.arn
}
