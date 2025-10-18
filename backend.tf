terraform {
  backend "s3" {
    bucket = "bucket"
    key    = "lambda-rds-apigw-infra/terraform.tfstate"
    region = "us-east-1"
  }
}
