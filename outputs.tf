output "vpc_id" {
  description = "ID of the example VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, keyed by availability zone."
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, keyed by availability zone."
  value       = { for az, subnet in aws_subnet.private : az => subnet.id }
}

output "internet_gateway_id" {
  description = "ID of the internet gateway used by the public subnets."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways, keyed by availability zone. Empty when enable_nat_gateway is false."
  value       = { for az, nat in aws_nat_gateway.this : az => nat.id }
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateways, keyed by availability zone. These are the source addresses for private subnet egress."
  value       = { for az, eip in aws_eip.nat : az => eip.public_ip }
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 gateway endpoint attached to the private route tables."
  value       = aws_vpc_endpoint.s3.id
}
