
module "aws-lambda-rds-apigw" {
  source  = "./modules/aws-lambda-rds-apigw"
  project = var.project
  #network
  vpc_cidr        = var.vpc_cidr
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  azs_count       = var.azs_count
  #api
  stage_name = var.stage_name
  #rds
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  max_allocated_storage   = var.max_allocated_storage
  backup_retention_period = var.backup_retention_period
  multi_az                = var.multi_az
  dbname                  = var.dbname
  engine                  = var.engine
  engine_version          = var.engine_version
  username                = var.username

  tags = local.tags
}
