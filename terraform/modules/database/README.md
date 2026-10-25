# database

A PostgreSQL RDS instance in the isolated data subnets.

- **Private and encrypted.** Not publicly accessible; storage, backups and the
  master password secret are encrypted with the data KMS key.
- **No password in code or state.** RDS generates the master password, stores it
  in Secrets Manager under the data key and rotates it every seven days. The
  module outputs the secret ARN, never the value.
- **TLS only.** The parameter group sets `rds.force_ssl = 1`, and the
  `rds-ca-rsa2048-g1` certificate authority is pinned so clients can verify it.
- **Recoverable.** Automated backups with point-in-time restore for
  `backup_retention_days`, tags copied to snapshots, and a final snapshot with a
  unique name when the instance is deleted (unless `skip_final_snapshot`).
  `deletion_protection` defaults to on.
- **Available.** `multi_az` adds a synchronous standby with automatic failover.
  Storage grows automatically up to `max_allocated_storage`.
- **Observable.** The `postgresql` and `upgrade` logs go to log groups created
  here first, so they have a retention period and encryption; RDS would
  otherwise create them with neither. Enhanced monitoring runs every 60 seconds.

Why `deletion_protection` and not `prevent_destroy`: `prevent_destroy` cannot be
set from a variable, so nobody could tear down a throwaway environment.

Changing `engine_version` across major versions or the instance class can restart
the database. `apply_immediately = false` queues such changes for the maintenance
window.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11, < 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.70 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.9 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_iam_role.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [random_id.final_snapshot](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_iam_policy_document.monitoring_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Days to keep automated backups. Also sets the point-in-time restore window. | `number` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | KMS key that encrypts the database storage and the master password secret. | `string` | n/a | yes |
| <a name="input_log_kms_key_arn"></a> [log\_kms\_key\_arn](#input\_log\_kms\_key\_arn) | KMS key that encrypts the database log groups. CloudWatch Logs must be allowed to use it. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Days to keep the database log groups. Must be a retention value CloudWatch Logs accepts. | `number` | n/a | yes |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Keep a synchronous standby in a second zone and fail over automatically. | `bool` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Prefix for resource names, for example info-api-dev. The instance identifier is <name>-db. | `string` | n/a | yes |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | Security group attached to the database. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Isolated subnets for the database, in at least two availability zones. | `list(string)` | n/a | yes |
| <a name="input_allocated_storage"></a> [allocated\_storage](#input\_allocated\_storage) | Initial storage in GiB. | `number` | `20` | no |
| <a name="input_apply_immediately"></a> [apply\_immediately](#input\_apply\_immediately) | Apply modifications now instead of in the next maintenance window. Some changes cause a restart. | `bool` | `false` | no |
| <a name="input_backup_window"></a> [backup\_window](#input\_backup\_window) | Daily UTC window for automated backups. Must not overlap maintenance\_window. | `string` | `"03:00-04:00"` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the initial database. | `string` | `"appdb"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Refuse to delete the instance while true. | `bool` | `true` | no |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | RDS instance class. | `string` | `"db.t4g.micro"` | no |
| <a name="input_maintenance_window"></a> [maintenance\_window](#input\_maintenance\_window) | Weekly UTC window for maintenance. Must not overlap backup\_window. | `string` | `"sun:05:00-sun:06:00"` | no |
| <a name="input_master_username"></a> [master\_username](#input\_master\_username) | Master user name. The password is generated and stored by RDS in Secrets Manager. | `string` | `"dbadmin"` | no |
| <a name="input_max_allocated_storage"></a> [max\_allocated\_storage](#input\_max\_allocated\_storage) | Storage autoscaling ceiling in GiB. Must be larger than allocated\_storage. | `number` | `50` | no |
| <a name="input_port"></a> [port](#input\_port) | TCP port the database listens on. | `number` | `5432` | no |
| <a name="input_postgres_major_version"></a> [postgres\_major\_version](#input\_postgres\_major\_version) | PostgreSQL major version. RDS picks the minor version and upgrades it automatically. | `string` | `"17"` | no |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Skip the snapshot taken when the instance is deleted. Leave false anywhere data matters. | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address"></a> [address](#output\_address) | DNS name of the database endpoint. It keeps pointing at the primary after a Multi-AZ failover. |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the DB instance. |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | Name of the initial database. |
| <a name="output_identifier"></a> [identifier](#output\_identifier) | DB instance identifier, as used by the RDS API. |
| <a name="output_master_secret_arn"></a> [master\_secret\_arn](#output\_master\_secret\_arn) | Secrets Manager secret holding the master credentials, created and rotated by RDS. |
| <a name="output_port"></a> [port](#output\_port) | TCP port the database listens on. |
<!-- END_TF_DOCS -->
