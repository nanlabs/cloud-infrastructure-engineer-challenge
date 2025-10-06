output "invoke_url" {
  value = "http://${aws_api_gateway_rest_api.this.id}.execute-api.localhost.localstack.cloud:4566/${aws_api_gateway_stage.stage.stage_name}/info"
}
