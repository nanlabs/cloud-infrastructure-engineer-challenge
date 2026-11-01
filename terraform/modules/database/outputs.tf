output "instance_id" {
  description = "RDS instance identifier (CloudWatch DBInstanceIdentifier dimension)."
  value       = aws_db_instance.this.identifier
}

output "arn" {
  description = "ARN of the RDS instance."
  value       = aws_db_instance.this.arn
}

output "address" {
  description = "Private DNS name of the database endpoint."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Database port."
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Name of the initial database."
  value       = aws_db_instance.this.db_name
}

output "engine_version" {
  description = "Running engine version."
  value       = aws_db_instance.this.engine_version_actual
}

output "instance_class" {
  description = "RDS instance class."
  value       = aws_db_instance.this.instance_class
}

output "multi_az" {
  description = "Whether the instance is Multi-AZ."
  value       = aws_db_instance.this.multi_az
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master credentials (managed by RDS)."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
