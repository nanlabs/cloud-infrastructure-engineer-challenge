output "api_gateway_url" {
  description = "The full URL of the API Gateway stage"
  value       = module.aws-lambda-rds-apigw.api_gateway_url
}
