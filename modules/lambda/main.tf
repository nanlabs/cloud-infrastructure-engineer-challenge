terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.5"
    }
  }
}

# DATA
data "aws_region" "current" {}

data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_function"
  output_path = "${path.module}/lambda_function.zip"
}

# IAM
resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.project}-lambda-policy"
  description = "Policy for accessing System manager to obtain credentials from DB"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Logging",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:CreateLogGroup",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Sid": "SecretsAccess",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecrets"
            ],
            "Resource": [
                "arn:aws:secretsmanager:*:*:secret:rds*"
            ]
        },
        {
          "Sid": "EC2PolicyStatement",
          "Effect": "Allow",
          "Action": [
            "ec2:CreateNetworkInterface",
            "ec2:AttachNetworkInterface",
            "ec2:DeleteNetworkInterface",
            "ec2:DetachNetworkInterface",
            "ec2:ModifyNetworkInterfaceAttribute"
          ],
            "Resource": [
                "arn:aws:ec2:*:*:elastic-ip/*",
                "arn:aws:ec2:*:*:instance/*",
                "arn:aws:ec2:*:*:network-interface/*",
                "arn:aws:ec2:*:*:prefix-list/*",
                "arn:aws:ec2:*:*:security-group-rule/*",
                "arn:aws:ec2:*:*:security-group/*",
                "arn:aws:ec2:*:*:subnet/*",
                "arn:aws:ec2:*:*:vpc/*",
                "arn:aws:ec2:*:*:vpc-endpoint/*",
                "arn:aws:ec2:*:*:*/*"
            ]
        },
        {
          "Sid": "EC2PolicyStatement2",
          "Effect": "Allow",
          "Action": [
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeSubnets",
            "ec2:DescribeVpcs",
            "ec2:DescribeDhcpOptions",
            "ec2:DescribeRouteTables"
          ],
          "Resource": "*"
        }
    ]
}
EOF
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "access_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


resource "aws_lambda_layer_version" "lambda_layer" {
  description         = "Python-PostgreSQL Database Adapter lambda layer"
  filename            = "${path.module}/lambda_layers/lambda-layer.zip"
  layer_name          = "psycopg2-lambda-layer"
  compatible_runtimes = ["python3.10"]
  source_code_hash    = filebase64sha256("${path.module}/lambda_layers/lambda-layer.zip")
}


## LAMBDA
resource "aws_lambda_function" "lambda-function" {
  function_name    = "${var.project}-lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  runtime          = "python3.10"
  timeout          = 360
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  vpc_config {
    subnet_ids         = var.subnet_ids #module.network.lambda_subnet_ids#
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      DB_ENDPOINT_ADDRESS = var.db_endpoint
      DB_NAME             = var.db_name
      DB_PORT             = var.db_port
      DB_SECRET_ARN       = var.db_instance_master_user_secret_arn
      REGION              = data.aws_region.current.id

    }
  }
  tags = var.tags
}
