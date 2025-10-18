terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

module "network" {
  source = "../../modules/network"

  project         = var.project
  vpc_cidr        = var.vpc_cidr
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  azs_count       = var.azs_count
  tags            = var.tags
}

module "lambda" {
  source                             = "../../modules/lambda"
  project                            = var.project
  subnet_ids                         = module.network.subnet_ids
  security_group_id                  = module.network.security_group_lambda_id
  db_endpoint                        = module.rds.db_endpoint
  db_name                            = module.rds.db_name
  db_port                            = module.rds.db_port
  db_instance_master_user_secret_arn = module.rds.db_instance_master_user_secret_arn
  tags                               = var.tags
}

module "api_gateway" {
  source               = "../../modules/api-gateway"
  project              = var.project
  stage_name           = var.stage_name
  lambda_invoke_arn    = module.lambda.lambda_invoke_arn
  lambda_function_name = module.lambda.lambda_function_name
  tags                 = var.tags

}

module "rds" {
  source                  = "../../modules/rds"
  project                 = var.project
  subnet_ids              = module.network.subnet_ids
  security_group_id       = module.network.security_group_rds_id
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  max_allocated_storage   = var.max_allocated_storage
  backup_retention_period = var.backup_retention_period
  storage_encrypted       = true
  multi_az                = var.multi_az
  dbname                  = var.dbname
  engine                  = var.engine
  engine_version          = var.engine_version
  username                = var.username

  tags = var.tags
}
