locals {
  name = "${var.project_name}-${var.env}"
}

module "logs" {
  source      = "./modules/logs"
  name_prefix = local.name
}

resource "docker_image" "backend" {
  provider     = docker.ls
  count        = var.use_localstack ? 1 : 0
  name         = "ghcr.io/nicholasjackson/fake-service:v0.26.2" 
  keep_locally = true
}

resource "docker_container" "backend" {
  provider = docker.ls
  count    = var.use_localstack ? 1 : 0
  name     = "${local.name}-backend"
  image    = docker_image.backend[0].name
  ports {
    internal = 9090
    external = 5001
  }
  env = [
    "LISTEN_ADDR=0.0.0.0:9090",
    "NAME=local-backend"
  ]
  # Esto queda “privado” respecto a AWS, pero accesible desde la Lambda de LocalStack
  # vía host.docker.internal o localhost (según versión)
}

module "vpc" {
  source          = "./modules/vpc"
  name            = local.name
  cidr_block      = "10.10.0.0/16"
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24"]
  public_subnets  = ["10.10.11.0/24", "10.10.12.0/24"]
  use_localstack  = var.use_localstack
}

module "lambda" {
  source             = "./modules/lambda"
  name               = "${local.name}-fn"
  memory_mb          = var.lambda_memory_mb
  timeout_sec        = var.lambda_timeout_sec
  log_group_name     = module.logs.log_group_name
  use_localstack     = var.use_localstack
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.lambda_sg_id]
  environment = {
    BACKEND_URL = "http://host.docker.internal:5001/version"

  }

}
module "api_gateway" {
  source      = "./modules/api_gateway"
  name        = "${local.name}-api"
  lambda_arn  = module.lambda.lambda_arn
  lambda_name = module.lambda.lambda_name
  stage_name  = "dev"

  providers = { aws = aws }
}