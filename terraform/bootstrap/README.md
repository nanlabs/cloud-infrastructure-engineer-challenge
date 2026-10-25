# bootstrap

Creates the S3 bucket and KMS key that hold the remote Terraform state for the
main configuration. It is a separate root with local state, so there is no
chicken-and-egg problem: run it once per AWS account, then point every
environment at the bucket it creates.

The bucket has versioning, KMS encryption, all public access blocked, ACLs
disabled, a policy that rejects non-TLS requests, and `prevent_destroy`.

State locking uses the S3 native lock file (`use_lockfile`), so no DynamoDB
table is needed.

## Usage

```bash
make bootstrap-plan BUCKET=<globally-unique-name>   # review the plan
make bootstrap-apply                                # applies the saved plan
```

From then on `make init` finds the bucket by itself, from this root's outputs.
On another machine, or in the GitHub workflow, set `STATE_BUCKET` and
`STATE_REGION` instead.

Keep `terraform/bootstrap/terraform.tfstate` (gitignored): it is the only record
of this bucket. Losing it does not delete the bucket, but you would have to
import it to manage it again.

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
| [aws_kms_alias.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Globally unique name of the Terraform state bucket. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region for the state bucket, for example us-east-1. | `string` | n/a | yes |
| <a name="input_noncurrent_version_retention_days"></a> [noncurrent\_version\_retention\_days](#input\_noncurrent\_version\_retention\_days) | Days to keep superseded state versions before they are deleted. | `number` | `90` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | <pre>{<br/>  "ManagedBy": "terraform",<br/>  "Project": "info-api-extended"<br/>}</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Name of the state bucket. make init uses it as STATE\_BUCKET. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | KMS key that encrypts the state bucket. |
| <a name="output_region"></a> [region](#output\_region) | Region of the state bucket. make init uses it as STATE\_REGION. |
<!-- END_TF_DOCS -->
