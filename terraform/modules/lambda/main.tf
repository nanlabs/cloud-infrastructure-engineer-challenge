data "archive_file" "this" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/.build/${var.name}.zip"

  lifecycle {
    precondition {
      condition     = fileexists("${var.source_dir}/handler.py")
      error_message = "Lambda package not found in ${var.source_dir}. Build it first: python scripts/build_lambda.py"
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
}

################################################################################
# IAM: execution role with least privilege
################################################################################

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# AWS managed policy for VPC functions: ENI management (needs "*") + CloudWatch Logs
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "read_db_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.secret_arn]
  }
}

resource "aws_iam_role_policy" "read_db_secret" {
  name   = "read-db-secret"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.read_db_secret.json
}

################################################################################
# Function
################################################################################

resource "aws_lambda_function" "this" {
  function_name    = var.name
  description      = var.description
  role             = aws_iam_role.this.arn
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256
  handler          = var.handler
  runtime          = var.runtime
  architectures    = [var.architecture]
  memory_size      = var.memory_size
  timeout          = var.timeout

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = merge(var.environment_variables, {
      DB_SECRET_ARN = var.secret_arn
    })
  }

  # Structured JSON logs, queryable with CloudWatch Logs Insights
  logging_config {
    log_format            = "JSON"
    log_group             = aws_cloudwatch_log_group.this.name
    application_log_level = "INFO"
    system_log_level      = "WARN"
  }

  # The role must be able to create ENIs before the function is placed in the VPC
  depends_on = [
    aws_iam_role_policy_attachment.vpc_access,
    aws_iam_role_policy.read_db_secret,
  ]
}
