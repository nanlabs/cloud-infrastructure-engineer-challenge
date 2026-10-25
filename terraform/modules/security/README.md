# security

Creates the two security groups and the complete set of rules between them.
Keeping every rule in one file means the whole access model can be reviewed in
one place, and the lambda and database modules need no knowledge of each other.

| Group | Direction | Port | Peer | Reason |
| ----- | --------- | ---- | ---- | ------ |
| lambda | egress | database port | database group | query the database |
| lambda | egress | 443 | 0.0.0.0/0 | Secrets Manager and RDS API through the NAT gateway |
| database | ingress | database port | lambda group | the only client |
| database | egress | none | none | replies to allowed connections need no rule |

Neither group has an ingress rule from a CIDR range. The 443 egress destination
is open because AWS publishes no prefix list for the Secrets Manager public
endpoint; VPC endpoints would let it be narrowed to the VPC.

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
| [aws_security_group.database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.lambda_to_aws_apis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.lambda_to_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.database_from_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Prefix for security group names, for example info-api-dev. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC the security groups belong to. | `string` | n/a | yes |
| <a name="input_db_port"></a> [db\_port](#input\_db\_port) | TCP port the database listens on. | `number` | `5432` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_database_security_group_id"></a> [database\_security\_group\_id](#output\_database\_security\_group\_id) | Security group to attach to the database. |
| <a name="output_lambda_security_group_id"></a> [lambda\_security\_group\_id](#output\_lambda\_security\_group\_id) | Security group to attach to the Lambda function. |
<!-- END_TF_DOCS -->
