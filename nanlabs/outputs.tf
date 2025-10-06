output "lambda_name" {
  value = module.lambda.lambda_name
}

output "backend_url_local" {
  description = "Solo localstack: URL del backend docker"
  value       = var.use_localstack ? "http://localhost:5001/version" : null
}

output "api_url" {
  description = "Invoke URL del GET /info (LocalStack)"
  value       = module.api_gateway.invoke_url
}
