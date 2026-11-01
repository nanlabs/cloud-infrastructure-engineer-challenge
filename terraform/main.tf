locals {
  name          = "${var.project}-${var.environment}"
  database_port = 5432
}

module "network" {
  source = "./modules/network"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
  database_port      = local.database_port
  log_retention_days = var.log_retention_days
}

module "database" {
  source = "./modules/database"

  name               = "${local.name}-postgres"
  subnet_ids         = module.network.database_subnet_ids
  security_group_ids = [module.network.database_security_group_id]
  port               = local.database_port

  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  skip_final_snapshot   = var.db_skip_final_snapshot
  log_retention_days    = var.log_retention_days
}

module "lambda" {
  source = "./modules/lambda"

  name               = "${local.name}-info"
  description        = "GET /info: database connection status and metadata"
  source_dir         = "${path.root}/../lambda/build"
  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.network.lambda_security_group_id]
  secret_arn         = module.database.master_user_secret_arn
  log_retention_days = var.log_retention_days

  environment_variables = {
    DB_HOST           = module.database.address
    DB_PORT           = tostring(module.database.port)
    DB_NAME           = module.database.database_name
    DB_INSTANCE_CLASS = module.database.instance_class
    DB_MULTI_AZ       = tostring(module.database.multi_az)
  }
}

module "api_gateway" {
  source = "./modules/api_gateway"

  name                   = local.name
  description            = "Public API exposing GET /info"
  lambda_function_name   = module.lambda.function_name
  lambda_invoke_arn      = module.lambda.invoke_arn
  throttling_rate_limit  = var.api_throttling_rate_limit
  throttling_burst_limit = var.api_throttling_burst_limit
  log_retention_days     = var.log_retention_days
}

module "cloudfront" {
  source = "./modules/cloudfront"

  origin_domain_name = trimprefix(module.api_gateway.api_endpoint, "https://")
  comment            = "${local.name} - edge entry point for the Info API"
}

module "monitoring" {
  source = "./modules/monitoring"

  name                 = local.name
  alarm_email          = var.alarm_email
  db_instance_id       = module.database.instance_id
  lambda_function_name = module.lambda.function_name
  api_id               = module.api_gateway.api_id
  api_stage            = module.api_gateway.stage_name
}
