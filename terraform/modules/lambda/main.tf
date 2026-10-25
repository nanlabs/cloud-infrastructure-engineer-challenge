locals {
  handler_module = join("/", slice(split(".", var.handler), 0, length(split(".", var.handler)) - 1))
  handler_file   = "${var.source_dir}/${local.handler_module}.py"
}

data "archive_file" "this" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/.terraform/lambda-${var.name}.zip"

  lifecycle {
    precondition {
      condition     = fileexists(local.handler_file)
      error_message = "${local.handler_file} not found. Build the package first with: make build"
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  # checkov:skip=CKV_AWS_338: retention is a variable; a year of function logs is not worth the cost here
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "permissions" {
  # checkov:skip=CKV_AWS_111: network interface actions cannot be limited to a resource
  # checkov:skip=CKV_AWS_356: network interface actions cannot be limited to a resource
  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }

  # Lambda creates and removes network interfaces in the VPC on the function's
  # behalf. AWS supports no resource-level limits for these actions.
  statement {
    sid = "ManageNetworkInterfaces"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.policy_statements

    content {
      sid       = statement.value.sid
      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "condition" {
        for_each = statement.value.conditions

        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "this" {
  name   = "permissions"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}

resource "aws_lambda_function" "this" {
  # checkov:skip=CKV_AWS_50: X-Ray tracing is not enabled
  # checkov:skip=CKV_AWS_115: reserved concurrency is a per-environment setting; small accounts cannot reserve any
  # checkov:skip=CKV_AWS_116: invoked synchronously by API Gateway, so a dead letter queue never receives anything
  # checkov:skip=CKV_AWS_173: the environment holds no secrets, only the secret's ARN
  # checkov:skip=CKV_AWS_272: code signing is out of scope for this challenge
  function_name = var.name
  role          = aws_iam_role.this.arn

  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256
  handler          = var.handler
  runtime          = var.runtime
  architectures    = ["arm64"]

  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = var.environment
  }

  logging_config {
    log_format            = "JSON"
    log_group             = aws_cloudwatch_log_group.this.name
    application_log_level = "INFO"
    system_log_level      = "WARN"
  }

  depends_on = [aws_iam_role_policy.this]
}
