# api

An HTTP API with one route that proxies to a Lambda function.

- **One route.** `route_key` (default `GET /info`) is the only route. The stage
  is `$default` with auto-deploy, so the URL has no stage prefix.
- **Least-privilege invoke.** The Lambda permission is limited to this API and
  this route (`<api>/*/GET/info`), not to the whole API.
- **Throttled.** The stage limits the steady rate and burst. Excess requests get
  HTTP 429 at the gateway, before they can become database connections.
- **Logged.** Every request is written as JSON (request id, status, latency,
  integration status and error) to an encrypted log group with a retention
  period.
- **Timeouts.** `integration_timeout_ms` must stay above the function timeout:
  otherwise the gateway answers 503 while the function keeps running, and the
  caller never sees the function's own error. HTTP APIs allow at most 30 s.

The route has no authorizer: the challenge asks for a working public endpoint,
and the response carries nothing sensitive. A JWT authorizer would be the next
step if that changed. HTTP APIs also cannot use AWS WAF; that needs a REST API
or CloudFront in front.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11, < 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.70 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_apigatewayv2_api.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_apigatewayv2_integration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_cloudwatch_log_group.access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_lambda_permission.invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_lambda_function_name"></a> [lambda\_function\_name](#input\_lambda\_function\_name) | Function API Gateway is allowed to invoke. | `string` | n/a | yes |
| <a name="input_lambda_invoke_arn"></a> [lambda\_invoke\_arn](#input\_lambda\_invoke\_arn) | Invoke ARN of the function. | `string` | n/a | yes |
| <a name="input_log_kms_key_arn"></a> [log\_kms\_key\_arn](#input\_log\_kms\_key\_arn) | KMS key that encrypts the access log group. CloudWatch Logs must be allowed to use it. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Days to keep access logs. Must be a retention value CloudWatch Logs accepts. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the API. Also names the access log group. | `string` | n/a | yes |
| <a name="input_throttling_burst_limit"></a> [throttling\_burst\_limit](#input\_throttling\_burst\_limit) | Short burst of requests the stage accepts above the steady rate. | `number` | n/a | yes |
| <a name="input_throttling_rate_limit"></a> [throttling\_rate\_limit](#input\_throttling\_rate\_limit) | Steady-state requests per second the stage accepts. Excess requests get HTTP 429. | `number` | n/a | yes |
| <a name="input_integration_timeout_ms"></a> [integration\_timeout\_ms](#input\_integration\_timeout\_ms) | How long API Gateway waits for the function. Keep it above the function timeout so the function's own error is what callers see. HTTP APIs allow at most 30000. | `number` | `16000` | no |
| <a name="input_route_key"></a> [route\_key](#input\_route\_key) | HTTP method and path served by the function, for example GET /info. | `string` | `"GET /info"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_access_log_group_name"></a> [access\_log\_group\_name](#output\_access\_log\_group\_name) | CloudWatch log group that receives the access logs. |
| <a name="output_api_endpoint"></a> [api\_endpoint](#output\_api\_endpoint) | Base URL of the API. The $default stage adds no path prefix. |
| <a name="output_api_id"></a> [api\_id](#output\_api\_id) | ID of the API. It is the ApiId dimension of the API Gateway metrics. |
| <a name="output_route_url"></a> [route\_url](#output\_route\_url) | Full URL of the route. |
<!-- END_TF_DOCS -->
