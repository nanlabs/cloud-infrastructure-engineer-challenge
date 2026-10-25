output "api_id" {
  description = "ID of the API. It is the ApiId dimension of the API Gateway metrics."
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "Base URL of the API. The $default stage adds no path prefix."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "route_url" {
  description = "Full URL of the route."
  value       = "${aws_apigatewayv2_api.this.api_endpoint}${local.route_path}"
}

output "access_log_group_name" {
  description = "CloudWatch log group that receives the access logs."
  value       = aws_cloudwatch_log_group.access.name
}
