

# 1) REST API
resource "aws_api_gateway_rest_api" "this" {
  name = var.name
}

# 2) Resource /info
resource "aws_api_gateway_resource" "info" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "info"
}

# 3) Método GET
resource "aws_api_gateway_method" "get_info" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.info.id
  http_method   = "GET"
  authorization = "NONE"
}

# 4) Integración Lambda (proxy)
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.info.id
  http_method = aws_api_gateway_method.get_info.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.lambda_arn}/invocations"
}

# 5) Permiso para que API GW invoque la Lambda
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvokeV1"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# 6) Deployment + Stage
resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  triggers = {
    redeploy_hash = sha1(jsonencode({
      int = aws_api_gateway_integration.lambda.id
      met = aws_api_gateway_method.get_info.id
    }))
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.deploy.id
  stage_name    = var.stage_name
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

