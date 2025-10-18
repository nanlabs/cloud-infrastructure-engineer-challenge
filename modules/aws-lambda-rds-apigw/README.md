<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_api_gateway"></a> [api\_gateway](#module\_api\_gateway) | ../../modules/api-gateway | n/a |
| <a name="module_lambda"></a> [lambda](#module\_lambda) | ../../modules/lambda | n/a |
| <a name="module_network"></a> [network](#module\_network) | ../../modules/network | n/a |
| <a name="module_rds"></a> [rds](#module\_rds) | ../../modules/rds | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allocated_storage"></a> [allocated\_storage](#input\_allocated\_storage) | n/a | `number` | `20` | no |
| <a name="input_azs_count"></a> [azs\_count](#input\_azs\_count) | Number of AZs to be created | `number` | `2` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | n/a | `number` | `7` | no |
| <a name="input_dbname"></a> [dbname](#input\_dbname) | n/a | `string` | `"postgres"` | no |
| <a name="input_engine"></a> [engine](#input\_engine) | n/a | `string` | `"postgres"` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | n/a | `string` | `"17.2"` | no |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | n/a | `string` | `"db.m5.large"` | no |
| <a name="input_max_allocated_storage"></a> [max\_allocated\_storage](#input\_max\_allocated\_storage) | n/a | `number` | `100` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | n/a | `bool` | `false` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | List of private subnets CIDR | `list(string)` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | n/a | `string` | `"cloud-infra-challenge"` | no |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | List of public subnets CIDR | `list(string)` | n/a | yes |
| <a name="input_stage_name"></a> [stage\_name](#input\_stage\_name) | n/a | `string` | `"dev"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags default | `map(string)` | `{}` | no |
| <a name="input_username"></a> [username](#input\_username) | n/a | `string` | `"postgres"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block of the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_gateway_url"></a> [api\_gateway\_url](#output\_api\_gateway\_url) | The full URL of the API Gateway stage |
<!-- END_TF_DOCS -->
