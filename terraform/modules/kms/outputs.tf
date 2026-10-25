output "key_arns" {
  description = "ARN of each key, by the name used in the keys input."
  value       = { for name, key in aws_kms_key.this : name => key.arn }
}
