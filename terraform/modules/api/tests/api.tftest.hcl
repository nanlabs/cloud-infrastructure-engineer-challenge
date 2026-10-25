mock_provider "aws" {
  mock_resource "aws_apigatewayv2_api" {
    defaults = {
      id            = "abc123defg"
      api_endpoint  = "https://abc123defg.execute-api.us-east-1.amazonaws.com"
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:abc123defg"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/apigateway/info-api-dev/access"
    }
  }
}

variables {
  name                   = "info-api-dev"
  lambda_function_name   = "info-api-dev-info"
  lambda_invoke_arn      = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:info-api-dev-info/invocations"
  throttling_rate_limit  = 5
  throttling_burst_limit = 10
  log_retention_days     = 14
  log_kms_key_arn        = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222"
}

run "serves_one_get_route_through_a_lambda_proxy" {
  command = plan

  assert {
    condition     = aws_apigatewayv2_api.this.protocol_type == "HTTP"
    error_message = "Expected an HTTP API."
  }

  assert {
    condition     = aws_apigatewayv2_route.this.route_key == "GET /info"
    error_message = "The only route must be GET /info."
  }

  assert {
    condition = (
      aws_apigatewayv2_integration.this.integration_type == "AWS_PROXY" &&
      aws_apigatewayv2_integration.this.integration_method == "POST" &&
      aws_apigatewayv2_integration.this.payload_format_version == "2.0" &&
      aws_apigatewayv2_integration.this.timeout_milliseconds == 16000
    )
    error_message = "Expected a Lambda proxy integration with payload 2.0 and a 16 s timeout."
  }
}

run "stage_throttles_and_logs_every_request" {
  command = plan

  assert {
    condition = (
      aws_apigatewayv2_stage.default.name == "$default" &&
      aws_apigatewayv2_stage.default.auto_deploy
    )
    error_message = "Expected an auto-deploying $default stage."
  }

  assert {
    condition = (
      aws_apigatewayv2_stage.default.default_route_settings[0].throttling_rate_limit == 5 &&
      aws_apigatewayv2_stage.default.default_route_settings[0].throttling_burst_limit == 10 &&
      aws_apigatewayv2_stage.default.default_route_settings[0].detailed_metrics_enabled
    )
    error_message = "Throttling and detailed metrics must follow the inputs."
  }

  assert {
    condition = (
      jsondecode(aws_apigatewayv2_stage.default.access_log_settings[0].format)["requestId"] == "$context.requestId" &&
      jsondecode(aws_apigatewayv2_stage.default.access_log_settings[0].format)["status"] == "$context.status"
    )
    error_message = "Access logs must be JSON and include the request id and status."
  }

  assert {
    condition = (
      aws_cloudwatch_log_group.access.retention_in_days == 14 &&
      aws_cloudwatch_log_group.access.kms_key_id == var.log_kms_key_arn
    )
    error_message = "The access log group needs the configured retention and the KMS key."
  }
}

run "only_this_route_may_invoke_the_function" {
  command = apply

  assert {
    condition = (
      aws_lambda_permission.invoke.principal == "apigateway.amazonaws.com" &&
      aws_lambda_permission.invoke.function_name == "info-api-dev-info" &&
      endswith(aws_lambda_permission.invoke.source_arn, "/*/GET/info")
    )
    error_message = "The invoke permission must be limited to the GET /info route."
  }

  assert {
    condition     = output.route_url == "https://abc123defg.execute-api.us-east-1.amazonaws.com/info"
    error_message = "route_url must be the API endpoint plus the route path."
  }
}

run "another_route_changes_the_permission_too" {
  command = apply

  variables {
    route_key = "POST /items"
  }

  assert {
    condition     = endswith(aws_lambda_permission.invoke.source_arn, "/*/POST/items")
    error_message = "The permission must follow the configured route."
  }
}

run "rejects_a_malformed_route" {
  command = plan

  variables {
    route_key = "/info"
  }

  expect_failures = [var.route_key]
}

run "rejects_a_route_with_a_catch_all_path" {
  command = plan

  variables {
    route_key = "ANY /{proxy+}"
  }

  expect_failures = [var.route_key]
}

run "rejects_an_integration_timeout_above_the_http_api_limit" {
  command = plan

  variables {
    integration_timeout_ms = 31000
  }

  expect_failures = [var.integration_timeout_ms]
}

run "rejects_zero_throttling" {
  command = plan

  variables {
    throttling_rate_limit = 0
  }

  expect_failures = [var.throttling_rate_limit]
}

run "rejects_unsupported_log_retention" {
  command = plan

  variables {
    log_retention_days = 10
  }

  expect_failures = [var.log_retention_days]
}
