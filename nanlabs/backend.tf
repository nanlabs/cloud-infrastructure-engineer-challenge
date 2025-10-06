terraform {
  backend "s3" {
    bucket         = "nanlabs-tfstate"
    key            = "infra/localstack/terraform.tfstate"
    region         = "us-east-1"
    endpoint       = "http://localhost:4566"
    access_key     = "test"
    secret_key     = "test"
    skip_credentials_validation = true
    force_path_style = true
  }
}
