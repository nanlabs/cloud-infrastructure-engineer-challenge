output "db_endpoint" {
  value = aws_db_instance.db_instance.address
}
output "db_port" {
  value = aws_db_instance.db_instance.port
}
output "db_name" {
  value = aws_db_instance.db_instance.db_name
}

output "db_instance_master_user_secret_arn" {
  description = "The ARN of the master user secret"
  value       = aws_db_instance.db_instance.master_user_secret[0].secret_arn
}
