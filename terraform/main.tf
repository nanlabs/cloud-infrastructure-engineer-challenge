terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
  }

  # Bucket, key and region are supplied at init time (make init, or the deploy
  # workflow), so this code holds no account-specific value.
  backend "s3" {}
}

provider "aws" {
  region = var.region

  # Refuses to run against any account that is not listed. Empty means no guard.
  allowed_account_ids = length(var.allowed_account_ids) > 0 ? var.allowed_account_ids : null

  default_tags {
    tags = local.tags
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"
  db_port     = 5432

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "cloud-infrastructure-engineer-challenge"
    Owner       = var.owner
  }
}

data "aws_caller_identity" "current" {}

module "kms" {
  source = "./modules/kms"

  name                    = local.name_prefix
  deletion_window_in_days = var.kms_deletion_window_in_days

  keys = {
    data = {
      description = "Encrypts the database storage and its master password secret"
    }
    observability = {
      description             = "Encrypts log groups and the alarm notification topic"
      allow_cloudwatch_logs   = true
      allow_cloudwatch_alarms = true
    }
  }
}

module "network" {
  source = "./modules/network"

  name                    = local.name_prefix
  cidr_block              = var.vpc_cidr_block
  az_count                = var.az_count
  nat_gateway_mode        = var.nat_gateway_mode
  flow_log_retention_days = var.flow_log_retention_days
  log_kms_key_arn         = module.kms.key_arns["observability"]
}

module "security" {
  source = "./modules/security"

  name    = local.name_prefix
  vpc_id  = module.network.vpc_id
  db_port = local.db_port
}

module "database" {
  source = "./modules/database"

  name                  = local.name_prefix
  subnet_ids            = module.network.data_subnet_ids
  security_group_id     = module.security.database_security_group_id
  kms_key_arn           = module.kms.key_arns["data"]
  log_kms_key_arn       = module.kms.key_arns["observability"]
  port                  = local.db_port
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  skip_final_snapshot   = var.db_skip_final_snapshot
  apply_immediately     = var.db_apply_immediately
  log_retention_days    = var.log_retention_days
}

module "lambda" {
  source = "./modules/lambda"

  name                           = "${local.name_prefix}-info"
  source_dir                     = var.lambda_package_dir
  subnet_ids                     = module.network.app_subnet_ids
  security_group_id              = module.security.lambda_security_group_id
  timeout                        = var.lambda_timeout_seconds
  reserved_concurrent_executions = var.lambda_reserved_concurrency
  log_retention_days             = var.log_retention_days
  log_kms_key_arn                = module.kms.key_arns["observability"]

  environment = {
    DB_HOST        = module.database.address
    DB_PORT        = tostring(module.database.port)
    DB_NAME        = module.database.database_name
    DB_SECRET_ARN  = module.database.master_secret_arn
    DB_INSTANCE_ID = module.database.identifier
  }

  policy_statements = [
    {
      sid       = "ReadDatabaseSecret"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [module.database.master_secret_arn]
    },
    {
      sid       = "DecryptDatabaseSecret"
      actions   = ["kms:Decrypt"]
      resources = [module.kms.key_arns["data"]]
      conditions = [{
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["secretsmanager.${var.region}.amazonaws.com"]
      }]
    },
    {
      sid       = "DescribeDatabaseInstance"
      actions   = ["rds:DescribeDBInstances"]
      resources = [module.database.arn]
    },
  ]
}

module "api" {
  source = "./modules/api"

  name                   = "${local.name_prefix}-info"
  lambda_function_name   = module.lambda.function_name
  lambda_invoke_arn      = module.lambda.invoke_arn
  integration_timeout_ms = (var.lambda_timeout_seconds + 1) * 1000
  throttling_rate_limit  = var.api_throttling_rate_limit
  throttling_burst_limit = var.api_throttling_burst_limit
  log_retention_days     = var.log_retention_days
  log_kms_key_arn        = module.kms.key_arns["observability"]
}

module "monitoring" {
  source = "./modules/monitoring"

  name                      = local.name_prefix
  kms_key_arn               = module.kms.key_arns["observability"]
  alert_email               = var.alert_email
  db_instance_identifier    = module.database.identifier
  db_connections_threshold  = var.db_connections_alarm_threshold
  lambda_function_name      = module.lambda.function_name
  lambda_timeout_seconds    = var.lambda_timeout_seconds
  lambda_log_group_name     = module.lambda.log_group_name
  api_id                    = module.api.api_id
  api_access_log_group_name = module.api.access_log_group_name
  nat_gateway_ids           = module.network.nat_gateway_ids
}
