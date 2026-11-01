output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "availability_zones" {
  description = "Availability Zones used by the subnets."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (NAT Gateways)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (Lambda)."
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs of the isolated database subnets."
  value       = aws_subnet.database[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IPs used by workloads in the private subnets to reach the internet."
  value       = aws_eip.nat[*].public_ip
}

output "lambda_security_group_id" {
  description = "Security group to attach to the Lambda function."
  value       = aws_security_group.lambda.id
}

output "database_security_group_id" {
  description = "Security group to attach to the database."
  value       = aws_security_group.database.id
}
