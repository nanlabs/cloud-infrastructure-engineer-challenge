# lambda

Packages a built directory into a zip and runs it as a Lambda function inside
the VPC, with a log group and an execution role that Terraform manages.

- **Package.** `source_dir` is the output of `make build`. If the handler file is
  missing, planning stops with a message that says to run it, instead of a
  generic archive error.
- **Runtime.** Python 3.13 on arm64 (Graviton), JSON logs. The function writes to
  a log group created here, so it has a retention period and encryption;
  Lambda would otherwise create one with neither.
- **Network.** The function's interfaces live in the given private subnets and
  use the given security group. Internet access comes from the route to the NAT
  gateway in those subnets.
- **Permissions.** The role can write to its own log group and manage network
  interfaces (AWS supports no resource limits for those actions). Anything else
  comes in through `policy_statements`, so each caller grants exactly what its
  function needs, scoped to specific ARNs.
- **Concurrency.** `reserved_concurrent_executions` caps how many copies run at
  once, which also caps database connections: one warm instance holds one
  connection. Reserving needs at least 100 unreserved executions left in the
  account, so small accounts must leave it at -1.

The package zip is written to `.terraform/` of the root and is not committed.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11, < 2.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.8 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.70 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [archive_file.this](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_log_kms_key_arn"></a> [log\_kms\_key\_arn](#input\_log\_kms\_key\_arn) | KMS key that encrypts the log group. CloudWatch Logs must be allowed to use it. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Days to keep the function's logs. Must be a retention value CloudWatch Logs accepts. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Function name. Also names the IAM role and the log group. | `string` | n/a | yes |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | Security group attached to the function's network interfaces. | `string` | n/a | yes |
| <a name="input_source_dir"></a> [source\_dir](#input\_source\_dir) | Directory holding the built package (code and dependencies). Created by make build. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Private subnets the function's network interfaces are placed in. | `list(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment variables. Must not hold secrets. | `map(string)` | `{}` | no |
| <a name="input_handler"></a> [handler](#input\_handler) | Handler in module.function form. The module path decides which file must exist in source\_dir. | `string` | `"info_api.handler.lambda_handler"` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Memory in MB. CPU scales with it. | `number` | `256` | no |
| <a name="input_policy_statements"></a> [policy\_statements](#input\_policy\_statements) | Extra IAM statements for the execution role, on top of logging and network access. | <pre>list(object({<br/>    sid       = string<br/>    actions   = list(string)<br/>    resources = list(string)<br/>    conditions = optional(list(object({<br/>      test     = string<br/>      variable = string<br/>      values   = list(string)<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_reserved_concurrent_executions"></a> [reserved\_concurrent\_executions](#input\_reserved\_concurrent\_executions) | Cap on concurrent executions, which also caps database connections. -1 leaves it unreserved. | `number` | `-1` | no |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Lambda runtime. | `string` | `"python3.13"` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Function timeout in seconds. Keep it below the API integration timeout. | `number` | `15` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_function_arn"></a> [function\_arn](#output\_function\_arn) | ARN of the function. |
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | Name of the function. |
| <a name="output_invoke_arn"></a> [invoke\_arn](#output\_invoke\_arn) | ARN API Gateway uses to invoke the function. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | CloudWatch log group the function writes to. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the execution role. |
<!-- END_TF_DOCS -->
