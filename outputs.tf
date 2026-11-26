output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnets
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT gateways, for allow-listing egress."
  value       = module.vpc.nat_public_ips
}

output "default_security_group_id" {
  description = "ID of the locked-down default security group."
  value       = module.vpc.default_security_group_id
}

output "kms_key_arn" {
  description = "ARN of the stack customer managed KMS key."
  value       = aws_kms_key.stack.arn
}

output "flow_log_group_name" {
  description = "Name of the CloudWatch log group receiving VPC flow logs."
  value       = aws_cloudwatch_log_group.flow_log.name
}
