# terraform

Root module. It only wires the modules in `modules/` together; resources live
in the modules and per-environment values live in `environments/<env>/`.

```bash
make init ENV=dev REGION=us-east-1   # connects to the shared state
```

Run `make bootstrap-plan` first if the state bucket does not exist yet. See the
top-level README for the full deployment steps.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11, < 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.70 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_api"></a> [api](#module\_api) | ./modules/api | n/a |
| <a name="module_database"></a> [database](#module\_database) | ./modules/database | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ./modules/kms | n/a |
| <a name="module_lambda"></a> [lambda](#module\_lambda) | ./modules/lambda | n/a |
| <a name="module_monitoring"></a> [monitoring](#module\_monitoring) | ./modules/monitoring | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./modules/network | n/a |
| <a name="module_security"></a> [security](#module\_security) | ./modules/security | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_api_throttling_burst_limit"></a> [api\_throttling\_burst\_limit](#input\_api\_throttling\_burst\_limit) | Short burst of requests the API accepts above the steady rate. | `number` | n/a | yes |
| <a name="input_api_throttling_rate_limit"></a> [api\_throttling\_rate\_limit](#input\_api\_throttling\_rate\_limit) | Requests per second the API accepts. Excess requests get HTTP 429 before they reach the database. | `number` | n/a | yes |
| <a name="input_db_backup_retention_days"></a> [db\_backup\_retention\_days](#input\_db\_backup\_retention\_days) | Days to keep automated database backups (1-35). Sets the point-in-time restore window. | `number` | n/a | yes |
| <a name="input_db_multi_az"></a> [db\_multi\_az](#input\_db\_multi\_az) | Run a synchronous standby in a second zone with automatic failover. | `bool` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment. Selects the settings profile in environments/<env>/. | `string` | n/a | yes |
| <a name="input_flow_log_retention_days"></a> [flow\_log\_retention\_days](#input\_flow\_log\_retention\_days) | Days to keep VPC flow logs. | `number` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Days to keep CloudWatch log groups other than VPC flow logs. | `number` | n/a | yes |
| <a name="input_nat_gateway_mode"></a> [nat\_gateway\_mode](#input\_nat\_gateway\_mode) | single shares one NAT gateway across zones (cheaper). per\_az gives each zone its own, so one zone failing does not cut egress for the others. | `string` | n/a | yes |
| <a name="input_owner"></a> [owner](#input\_owner) | Owner tag applied to every resource. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy into, for example us-east-1. | `string` | n/a | yes |
| <a name="input_alert_email"></a> [alert\_email](#input\_alert\_email) | Address that receives alarm notifications. AWS emails a confirmation link that must be clicked. Null creates the topic without a subscriber. | `string` | `null` | no |
| <a name="input_allowed_account_ids"></a> [allowed\_account\_ids](#input\_allowed\_account\_ids) | AWS account IDs Terraform may run against. Leave empty to disable the guard. | `list(string)` | `[]` | no |
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of availability zones to spread subnets across (2 or 3). | `number` | `2` | no |
| <a name="input_db_allocated_storage"></a> [db\_allocated\_storage](#input\_db\_allocated\_storage) | Initial database storage in GiB. | `number` | `20` | no |
| <a name="input_db_apply_immediately"></a> [db\_apply\_immediately](#input\_db\_apply\_immediately) | Apply database modifications now instead of in the next maintenance window. Some changes restart the database. | `bool` | `false` | no |
| <a name="input_db_connections_alarm_threshold"></a> [db\_connections\_alarm\_threshold](#input\_db\_connections\_alarm\_threshold) | Database connection count that raises an alarm: about 75% of max\_connections. The default of 60 suits db.t4g.micro and must be revisited with the instance class. | `number` | `60` | no |
| <a name="input_db_deletion_protection"></a> [db\_deletion\_protection](#input\_db\_deletion\_protection) | Refuse to delete the database while true. | `bool` | `true` | no |
| <a name="input_db_instance_class"></a> [db\_instance\_class](#input\_db\_instance\_class) | RDS instance class. | `string` | `"db.t4g.micro"` | no |
| <a name="input_db_max_allocated_storage"></a> [db\_max\_allocated\_storage](#input\_db\_max\_allocated\_storage) | Ceiling in GiB that database storage grows to automatically. | `number` | `50` | no |
| <a name="input_db_skip_final_snapshot"></a> [db\_skip\_final\_snapshot](#input\_db\_skip\_final\_snapshot) | Skip the snapshot taken when the database is deleted. Leave false anywhere data matters. | `bool` | `false` | no |
| <a name="input_kms_deletion_window_in_days"></a> [kms\_deletion\_window\_in\_days](#input\_kms\_deletion\_window\_in\_days) | Days a KMS key stays recoverable after deletion is scheduled (7-30). | `number` | `30` | no |
| <a name="input_lambda_package_dir"></a> [lambda\_package\_dir](#input\_lambda\_package\_dir) | Directory holding the built Lambda package. Created by make build. | `string` | `"../build/functions/info"` | no |
| <a name="input_lambda_reserved_concurrency"></a> [lambda\_reserved\_concurrency](#input\_lambda\_reserved\_concurrency) | Cap on concurrent Lambda executions, which also caps database connections. -1 leaves it unreserved; accounts with a low concurrency quota cannot reserve any. | `number` | `-1` | no |
| <a name="input_lambda_timeout_seconds"></a> [lambda\_timeout\_seconds](#input\_lambda\_timeout\_seconds) | Lambda timeout (3-29 seconds). API Gateway waits one second longer, so callers see the function's own error rather than a gateway timeout. | `number` | `15` | no |
| <a name="input_project"></a> [project](#input\_project) | Short project name used as the prefix of every resource name. | `string` | `"info-api-extended"` | no |
| <a name="input_vpc_cidr_block"></a> [vpc\_cidr\_block](#input\_vpc\_cidr\_block) | IPv4 CIDR of the VPC. Subnets are /24 blocks carved from it, so use /16 or larger. | `string` | `"10.20.0.0/16"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_id"></a> [account\_id](#output\_account\_id) | AWS account this configuration is applied to. Check it before approving a plan. |
| <a name="output_alarm_topic_arn"></a> [alarm\_topic\_arn](#output\_alarm\_topic\_arn) | SNS topic that receives every alarm. Subscribe to it, or set alert\_email. |
| <a name="output_api_access_log_group_name"></a> [api\_access\_log\_group\_name](#output\_api\_access\_log\_group\_name) | CloudWatch log group that receives the API access logs. |
| <a name="output_database_identifier"></a> [database\_identifier](#output\_database\_identifier) | RDS instance identifier. Use it with the RDS and CloudWatch APIs. |
| <a name="output_info_url"></a> [info\_url](#output\_info\_url) | URL of GET /info. |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Name of the Lambda function. |
| <a name="output_lambda_log_group_name"></a> [lambda\_log\_group\_name](#output\_lambda\_log\_group\_name) | CloudWatch log group the Lambda writes to. |
| <a name="output_nat_public_ips"></a> [nat\_public\_ips](#output\_nat\_public\_ips) | Public IPs of the NAT gateways. Allow-list these at any service the Lambda calls over the internet. |
| <a name="output_region"></a> [region](#output\_region) | AWS region this configuration is applied to. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC. |
<!-- END_TF_DOCS -->
