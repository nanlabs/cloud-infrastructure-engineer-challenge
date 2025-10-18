# Cloud Infrastructure Engineer Challenge

## Overview

The solution provisions a complete AWS architecture using **Terraform** (v1.5+) and **AWS provider v6.17.0**, following best practices for networking, security, and modularity.

## Architecture Description

The deployed architecture consists of the following components:

### Networking
- **VPC** with:
  - **2 Public Subnets** (one per AZ)
  - **2 Private Subnets** (one per AZ)
- **2 NAT Gateways** (one in each public subnet)
  This prevents cross-AZ data transfer costs and ensures high availability.
- Proper **route tables** and **security groups** for secure communication.

### Compute Layer
- **AWS Lambda Function**
  - Deployed in **private subnets**.
  - Accesses the RDS database securely within the VPC.
  - Uses a **Lambda Layer** for database driver dependencies.
  - Retrieves database credentials from **AWS Secrets Manager**.
  - Sends logs to **CloudWatch Logs** for observability.

### API Layer
- **API Gateway** configured with a **GET /info** endpoint.
  - Triggers the Lambda function.
  - Returns a JSON response containing:
    - Connection status to the database
    - Endpoint of the DB
    - DB version

### Database Layer
- **Amazon RDS for PostgreSQL**
  - Deployed within **private subnets** for enhanced security and isolation.
  - Integrates with **AWS Secrets Manager** for automatic password generation and rotation, as described in the [official AWS announcement](https://aws.amazon.com/about-aws/whats-new/2022/12/amazon-rds-integration-aws-secrets-manager/).
  - Avoids hardcoding credentials or storing them in Terraform state (`tfstate`).
  - Uses **non–T-series instance types** (e.g., `m5`, `r6g`) to avoid issues with CPU credit depletion that can cause performance throttling.


## Design Considerations

- **Security**:
  - Lambda runs in a private subnet with no direct internet exposure.
  - Secrets are never exposed in Terraform state or code.
  - **NAT Gateway** allows outbound traffic for:
    - Lambda’s dependency downloads.
    - Secure access to **AWS Secrets Manager** to retrieve database credentials.

- **Performance & Cost Optimization**:
  - Each AZ has its own NAT Gateway to reduce inter-AZ data transfer.
  - Selected instance types are optimized for steady CPU performance.
  - Logging enabled for observability but scoped to avoid unnecessary retention costs.

- **Modularity**:
  - The Terraform codebase is modular:
    - `networking/` → Networking components
    - `lambda/` → Function, IAM roles, and layers
    - `api-gateway/` → API configuration
    - `rds/` → Database
    - `aws-lambda-rds-apigw/` → Module that provisions the complete architecture

## Automation

To ensure consistent formatting, validation, and security checks across the infrastructure codebase, this project includes both **pre-commit hooks** and a **GitHub Actions CI pipeline**.

### Pre-commit Hooks

The repository includes a `.pre-commit-config.yaml` that automatically runs Terraform formatting, validation, linting, and documentation generation for all modules before commits are pushed.

### Continuous Integration (CI)

The **GitHub Actions** workflow (`.github/workflows/terrafrom-ci.yaml`) runs multiple Terraform checks whenever a pull request targets the `main` branch and includes changes under `modules/**/*.tf`.

#### Workflow Summary

| Job | Description |
|-----|--------------|
| `terraform-fmt` | Checks Terraform file formatting |
| `terraform-validate` | Validates module configurations |
| `terraform-tflint` | Runs linting with TFLint |
| `tfsec` | Performs static security analysis |
| `checkov` | Runs policy-as-code security scanning |
| `terraform-docs` | Generates and injects module documentation |


## Prerequisites

1. AWS CLI configured
2. A bucket to be used as the backend for the tfstate

## Usage

```bash
# Initialize Terraform
terraform init
# In case provider versions need to be upgraded, use:
terraform init --upgrade

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

## Get API Endpoint

After deployment, Terraform will output the API endpoint:

**Output:**
```terraform
api_invoke_url = "https://<api-id>.execute-api.<region>.amazonaws.com/<stage>"
```
You can test it using the provided **`test-api.py`** script.

**Expected response:**
```json

{
  "connection_status": "Connected",
  "database_host": "cloud-infra-challenge-db-rds.csbomcegqt01.us-east-1.rds.amazonaws.com",
  "database_version": "PostgreSQL 17.2 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 12.4.0, 64-bit"
}
```

## Recommendations

- **Enable Multi-AZ** for RDS in production to improve availability, aligning with the existing design that includes a NAT Gateway per Availability Zone.
- **Add CloudWatch Alarms** for Lambda errors and RDS CPU utilization.
- **Use RDS Proxy with Lambda** to reduce the load on the database server since a new connection is not created for every Lambda invocation, improving scalability and performance.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aws-lambda-rds-apigw"></a> [aws-lambda-rds-apigw](#module\_aws-lambda-rds-apigw) | ./modules/aws-lambda-rds-apigw | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allocated_storage"></a> [allocated\_storage](#input\_allocated\_storage) | n/a | `number` | `20` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The AWS region to create things in. | `string` | `"us-east-1"` | no |
| <a name="input_azs_count"></a> [azs\_count](#input\_azs\_count) | Number of AZs to be created | `number` | `2` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | n/a | `number` | `7` | no |
| <a name="input_dbname"></a> [dbname](#input\_dbname) | n/a | `string` | `"postgres"` | no |
| <a name="input_engine"></a> [engine](#input\_engine) | n/a | `string` | `"postgres"` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | n/a | `string` | `"17.2"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | n/a | `string` | `"dev"` | no |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | n/a | `string` | `"db.m5.large"` | no |
| <a name="input_max_allocated_storage"></a> [max\_allocated\_storage](#input\_max\_allocated\_storage) | n/a | `number` | `100` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | n/a | `bool` | `false` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | n/a | `string` | `""` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | List of private subnets CIDR | `list(string)` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | n/a | `string` | `"cloud-infra-challenge"` | no |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | List of public subnets CIDR | `list(string)` | n/a | yes |
| <a name="input_stage_name"></a> [stage\_name](#input\_stage\_name) | n/a | `string` | `"dev"` | no |
| <a name="input_username"></a> [username](#input\_username) | n/a | `string` | `"postgres"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block of the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_gateway_url"></a> [api\_gateway\_url](#output\_api\_gateway\_url) | The full URL of the API Gateway stage |
<!-- END_TF_DOCS -->
