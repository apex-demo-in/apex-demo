output "vpc_id" {
  description = "ID of the example VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, keyed by availability zone."
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, keyed by availability zone. These have no outbound internet route."
  value       = { for az, subnet in aws_subnet.private : az => subnet.id }
}

output "internet_gateway_id" {
  description = "ID of the internet gateway used by the public subnets."
  value       = aws_internet_gateway.this.id
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 gateway endpoint attached to the private route tables."
  value       = aws_vpc_endpoint.s3.id
}
