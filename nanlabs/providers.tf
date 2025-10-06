variable "use_localstack" {
  type        = bool
  description = "true = apunta a LocalStack; false = AWS real"
  default     = true
}

variable "region" {
  type    = string
  default = "us-east-1"
}

locals {
  ls_endpoint = "http://localhost:4566"
}

provider "aws" {
  region                      = var.region
  access_key                  = var.use_localstack ? "test" : null
  secret_key                  = var.use_localstack ? "test" : null
  skip_credentials_validation = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  s3_use_path_style           = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      apigateway   = local.ls_endpoint
      apigatewayv2 = local.ls_endpoint # <-- importante
      cloudwatch   = local.ls_endpoint
      logs         = local.ls_endpoint
      lambda       = local.ls_endpoint
      iam          = local.ls_endpoint
      sts          = local.ls_endpoint # <-- ayuda a evitar llamadas a AWS real
      s3           = local.ls_endpoint
      dynamodb     = local.ls_endpoint
    }
  }
}

provider "docker" {
  host  = "unix:///var/run/docker.sock"
  alias = "ls"
}
