output "api_invoke_url" {
  description = "The URL to invoke the API Gateway"
  value       = aws_api_gateway_stage.stage.invoke_url
}

output "api_id" {
  description = "The ID of the API Gateway"
  value       = aws_api_gateway_rest_api.api.id
}
