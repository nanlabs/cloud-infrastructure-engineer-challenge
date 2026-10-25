# kms

Creates one customer-managed KMS key per entry in `keys`, with annual rotation
and an explicit key policy.

Every key grants the account's IAM policies full control, which is how the
Lambda role and the database get access through their own permissions.
Service access is opt-in per key:

- `allow_cloudwatch_logs`: lets CloudWatch Logs encrypt log groups in this
  account and region. The statement is limited to log group ARNs.
- `allow_cloudwatch_alarms`: lets CloudWatch alarms publish to an SNS topic
  encrypted with the key. The AWS-managed `alias/aws/sns` key cannot be used
  for that, because its policy does not allow the alarms service.

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
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_keys"></a> [keys](#input\_keys) | Keys to create, by purpose. The key name becomes part of the alias.<br/>allow\_cloudwatch\_logs lets CloudWatch Logs encrypt log groups in this account with the key.<br/>allow\_cloudwatch\_alarms lets CloudWatch alarms publish to an SNS topic encrypted with the key. | <pre>map(object({<br/>    description             = string<br/>    allow_cloudwatch_logs   = optional(bool, false)<br/>    allow_cloudwatch_alarms = optional(bool, false)<br/>  }))</pre> | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Prefix for key alias names, for example info-api-dev. | `string` | n/a | yes |
| <a name="input_deletion_window_in_days"></a> [deletion\_window\_in\_days](#input\_deletion\_window\_in\_days) | Days a key stays recoverable after it is scheduled for deletion. | `number` | `30` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_arns"></a> [key\_arns](#output\_key\_arns) | ARN of each key, by the name used in the keys input. |
<!-- END_TF_DOCS -->
