output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs, ordered by availability zone."
  value       = [for az in local.azs : aws_subnet.public[az].id]
}

output "app_subnet_ids" {
  description = "Private application subnet IDs (Lambda), ordered by availability zone."
  value       = [for az in local.azs : aws_subnet.app[az].id]
}

output "data_subnet_ids" {
  description = "Isolated data subnet IDs (database), ordered by availability zone."
  value       = [for az in local.azs : aws_subnet.data[az].id]
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs, ordered by availability zone. Used to alarm on port exhaustion."
  value       = [for az in local.azs : aws_nat_gateway.this[az].id if contains(keys(aws_nat_gateway.this), az)]
}

output "nat_public_ips" {
  description = "Public IPs that outbound traffic from the application subnets appears to come from."
  value       = [for az, eip in aws_eip.nat : eip.public_ip]
}
