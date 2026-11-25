output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the two private subnets."
  value       = module.vpc.private_subnets
}

output "private_route_table_ids" {
  description = "IDs of the route tables associated with the private subnets."
  value       = module.vpc.private_route_table_ids
}

output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key for this stack."
  value       = aws_kms_key.stack.arn
}
