data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_kms_alias" "rds_default_key" {
  name = "alias/aws/rds"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_rds_connect_policy" {
  statement {
    effect    = "Allow"
    actions   = ["rds-db:connect"]
    resources = ["arn:aws:rds-db:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.nanlabs-rds.id}/${postgresql_role.nanlabs_user.name}"]
  }
  depends_on = [ aws_db_instance.nanlabs-rds, postgresql_role.nanlabs_user ]
}

# para la customer managed policy
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# zippeo el codigo de mi lambda para subirlo durante la creación
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "./function_code/"
  output_path = "./function_code/lambda_function.zip"
}