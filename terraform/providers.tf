provider "aws" {
  region = var.aws_region

  # Tags applied to every taggable resource: cost allocation and ownership
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "github.com/WinstonSShaw/cloud-infrastructure-engineer-challenge"
    }
  }
}
