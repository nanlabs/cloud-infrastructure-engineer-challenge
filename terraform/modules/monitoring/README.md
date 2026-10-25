# monitoring

An encrypted SNS topic, CloudWatch alarms that publish to it, and saved Logs
Insights queries.

| Alarm | Fires when | Why |
| ----- | ---------- | --- |
| `rds-cpu-high` | CPU average above 80% for 15 minutes | A saturated database slows every request |
| `rds-storage-low` | Free storage under 2 GiB | Backstop for storage autoscaling reaching its ceiling |
| `rds-memory-low` | Freeable memory under 64 MiB for 15 minutes | The micro class has 1 GiB |
| `rds-connections-high` | Connections above the threshold (default 60) | Close to `max_connections`; see below |
| `lambda-errors` | Any function error in 5 minutes | Handler failures |
| `lambda-throttles` | Any throttled request in 5 minutes | The concurrency cap was reached |
| `lambda-duration-p99` | p99 above 80% of the timeout for 15 minutes | About to start timing out |
| `api-5xx` | Any 5xx in 5 minutes | Errors callers see |
| `nat-port-allocation-<n>` | Any failed port allocation | Too many concurrent connections through the NAT gateway |

Every alarm notifies on recovery too. Missing data counts as healthy, because a
quiet system sends no data points.

The connection threshold of 60 is about 75% of the roughly 80 usable
connections of a `db.t4g.micro`. `max_connections` is
`LEAST(DBInstanceClassMemory/9531392, 5000)`; check the real value with
`SHOW max_connections;` and revisit the threshold when changing the instance
class.

The topic uses its own KMS key with an alarm statement, because the
AWS-managed SNS key does not let CloudWatch publish. An email subscription must
be confirmed from the message AWS sends; Terraform cannot do that step.

Three saved queries appear under CloudWatch Logs Insights: recent warnings and
errors, database failures by category, and API latency percentiles. They have
been checked for syntax by Terraform only; confirm they return rows against real
logs after the first deployment.

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
| [aws_cloudwatch_metric_alarm.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_query_definition.api_latency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_query_definition) | resource |
| [aws_cloudwatch_query_definition.database_failures](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_query_definition) | resource |
| [aws_cloudwatch_query_definition.recent_problems](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_query_definition) | resource |
| [aws_sns_topic.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_subscription.email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_api_access_log_group_name"></a> [api\_access\_log\_group\_name](#input\_api\_access\_log\_group\_name) | Log group the saved query searches for API latency. | `string` | n/a | yes |
| <a name="input_api_id"></a> [api\_id](#input\_api\_id) | HTTP API to watch. | `string` | n/a | yes |
| <a name="input_db_instance_identifier"></a> [db\_instance\_identifier](#input\_db\_instance\_identifier) | RDS instance to watch. | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | KMS key that encrypts the alert topic. CloudWatch alarms must be allowed to use it. | `string` | n/a | yes |
| <a name="input_lambda_function_name"></a> [lambda\_function\_name](#input\_lambda\_function\_name) | Lambda function to watch. | `string` | n/a | yes |
| <a name="input_lambda_log_group_name"></a> [lambda\_log\_group\_name](#input\_lambda\_log\_group\_name) | Log group the saved queries search for the function. | `string` | n/a | yes |
| <a name="input_lambda_timeout_seconds"></a> [lambda\_timeout\_seconds](#input\_lambda\_timeout\_seconds) | Timeout of the function. The duration alarm fires at 80% of it. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Prefix for alarm and topic names, for example info-api-dev. | `string` | n/a | yes |
| <a name="input_nat_gateway_ids"></a> [nat\_gateway\_ids](#input\_nat\_gateway\_ids) | NAT gateways to watch for port exhaustion. | `list(string)` | n/a | yes |
| <a name="input_alert_email"></a> [alert\_email](#input\_alert\_email) | Address that receives alerts. The subscription must be confirmed from the email AWS sends. Null creates the topic without a subscriber. | `string` | `null` | no |
| <a name="input_db_connections_threshold"></a> [db\_connections\_threshold](#input\_db\_connections\_threshold) | Connection count that raises an alarm. Set it near 75% of max\_connections for the instance class. | `number` | `60` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alarm_names"></a> [alarm\_names](#output\_alarm\_names) | Names of all alarms, sorted. |
| <a name="output_topic_arn"></a> [topic\_arn](#output\_topic\_arn) | SNS topic that receives every alarm and recovery. |
<!-- END_TF_DOCS -->
