output "api_id" {
  description = "ID of the HTTP API (CloudWatch ApiId dimension)."
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "Base URL of the HTTP API, e.g. https://abc123.execute-api.us-east-1.amazonaws.com"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "stage_name" {
  description = "Name of the deployed stage."
  value       = aws_apigatewayv2_stage.default.name
}

output "access_log_group_name" {
  description = "CloudWatch log group with the API access logs."
  value       = aws_cloudwatch_log_group.access_logs.name
}
