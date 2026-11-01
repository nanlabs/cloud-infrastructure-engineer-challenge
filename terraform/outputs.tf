output "info_url" {
  description = "Public entry point: GET /info through CloudFront."
  value       = "https://${module.cloudfront.domain_name}/info"
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = module.cloudfront.distribution_id
}

output "api_gateway_info_url" {
  description = "GET /info served directly by API Gateway."
  value       = "${module.api_gateway.api_endpoint}/info"
}

output "api_access_log_group" {
  description = "CloudWatch log group with the API Gateway access logs."
  value       = module.api_gateway.access_log_group_name
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "nat_gateway_public_ips" {
  description = "Egress public IPs of the private subnets."
  value       = module.network.nat_gateway_public_ips
}

output "database_endpoint" {
  description = "Private endpoint of the PostgreSQL instance (only reachable from inside the VPC)."
  value       = "${module.database.address}:${module.database.port}"
}

output "database_secret_arn" {
  description = "Secrets Manager secret with the database master credentials (managed by RDS)."
  value       = module.database.master_user_secret_arn
}

output "lambda_function_name" {
  description = "Name of the Info Lambda function."
  value       = module.lambda.function_name
}

output "lambda_log_group" {
  description = "CloudWatch log group with the Lambda logs."
  value       = module.lambda.log_group_name
}

output "alarms_sns_topic_arn" {
  description = "SNS topic receiving the CloudWatch alarm notifications."
  value       = module.monitoring.sns_topic_arn
}
