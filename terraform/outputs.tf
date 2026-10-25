output "info_url" {
  description = "URL of GET /info."
  value       = module.api.route_url
}

output "account_id" {
  description = "AWS account this configuration is applied to. Check it before approving a plan."
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS region this configuration is applied to."
  value       = var.region
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateways. Allow-list these at any service the Lambda calls over the internet."
  value       = module.network.nat_public_ips
}

output "database_identifier" {
  description = "RDS instance identifier. Use it with the RDS and CloudWatch APIs."
  value       = module.database.identifier
}

output "lambda_function_name" {
  description = "Name of the Lambda function."
  value       = module.lambda.function_name
}

output "lambda_log_group_name" {
  description = "CloudWatch log group the Lambda writes to."
  value       = module.lambda.log_group_name
}

output "api_access_log_group_name" {
  description = "CloudWatch log group that receives the API access logs."
  value       = module.api.access_log_group_name
}

output "alarm_topic_arn" {
  description = "SNS topic that receives every alarm. Subscribe to it, or set alert_email."
  value       = module.monitoring.topic_arn
}
