output "lambda_security_group_id" {
  description = "Security group to attach to the Lambda function."
  value       = aws_security_group.lambda.id
}

output "database_security_group_id" {
  description = "Security group to attach to the database."
  value       = aws_security_group.database.id
}
