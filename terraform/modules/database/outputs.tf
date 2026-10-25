output "identifier" {
  description = "DB instance identifier, as used by the RDS API."
  value       = aws_db_instance.this.identifier
}

output "arn" {
  description = "ARN of the DB instance."
  value       = aws_db_instance.this.arn
}

output "address" {
  description = "DNS name of the database endpoint. It keeps pointing at the primary after a Multi-AZ failover."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "TCP port the database listens on."
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Name of the initial database."
  value       = aws_db_instance.this.db_name
}

output "master_secret_arn" {
  description = "Secrets Manager secret holding the master credentials, created and rotated by RDS."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
