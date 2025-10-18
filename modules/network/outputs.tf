output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.vpc.id
}

output "subnet_ids" {
  description = "Private subnet IDs dedicated to the Lambda function and RDS"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "security_group_lambda_id" {
  description = "The security group ID associated with the Lambda"
  value       = aws_security_group.security_group_lambda.id
}

output "security_group_rds_id" {
  description = "The security group ID associated with the RDS instance"
  value       = aws_security_group.security_group_rds.id
}
