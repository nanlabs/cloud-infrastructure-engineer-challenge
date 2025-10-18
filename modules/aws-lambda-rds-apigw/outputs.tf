# output "api_gateway_url" {
#   description = "The full URL of the API Gateway stage"
#   value       = "https://${module.api_gateway.api_id}.execute-api.${var.aws_region}.amazonaws.com/${var.stage_name}"
# }

output "api_gateway_url" {
  description = "The full URL of the API Gateway stage"
  value       = module.api_gateway.api_invoke_url
}
