mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-function"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name              = "info-api-dev-info"
  source_dir        = "tests/fixtures/package"
  subnet_ids        = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
  security_group_id = "sg-0123456789abcdef0"
  environment = {
    DB_HOST = "db.internal.example"
    DB_NAME = "appdb"
  }
  log_retention_days = 14
  log_kms_key_arn    = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222"
}

run "function_runs_the_expected_runtime_in_the_vpc" {
  command = plan

  assert {
    condition = (
      aws_lambda_function.this.runtime == "python3.13" &&
      aws_lambda_function.this.architectures == tolist(["arm64"]) &&
      aws_lambda_function.this.handler == "info_api.handler.lambda_handler" &&
      aws_lambda_function.this.memory_size == 256 &&
      aws_lambda_function.this.timeout == 15
    )
    error_message = "Expected python3.13 on arm64 with the default handler, 256 MB and a 15 s timeout."
  }

  assert {
    condition = (
      toset(aws_lambda_function.this.vpc_config[0].subnet_ids) == toset(var.subnet_ids) &&
      toset(aws_lambda_function.this.vpc_config[0].security_group_ids) == toset([var.security_group_id])
    )
    error_message = "The function must be attached to the given subnets and security group."
  }
}

run "settings_are_passed_to_the_function" {
  command = plan

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["DB_HOST"] == "db.internal.example"
    error_message = "Environment variables must reach the function."
  }

  assert {
    condition     = aws_lambda_function.this.reserved_concurrent_executions == -1
    error_message = "Concurrency is unreserved unless asked for."
  }
}

run "concurrency_cap_is_applied" {
  command = plan

  variables {
    reserved_concurrent_executions = 10
  }

  assert {
    condition     = aws_lambda_function.this.reserved_concurrent_executions == 10
    error_message = "The configured concurrency cap must be applied."
  }
}

run "logs_are_json_in_an_encrypted_managed_group" {
  command = plan

  assert {
    condition = (
      aws_lambda_function.this.logging_config[0].log_format == "JSON" &&
      aws_lambda_function.this.logging_config[0].log_group == "/aws/lambda/info-api-dev-info"
    )
    error_message = "The function must write JSON logs to the group Terraform manages."
  }

  assert {
    condition = (
      aws_cloudwatch_log_group.this.retention_in_days == 14 &&
      aws_cloudwatch_log_group.this.kms_key_id == var.log_kms_key_arn
    )
    error_message = "The log group needs the configured retention and the KMS key."
  }
}

run "extra_permissions_are_added_to_the_base_set" {
  command = plan

  variables {
    policy_statements = [
      {
        sid       = "ReadSecret"
        actions   = ["secretsmanager:GetSecretValue"]
        resources = ["arn:aws:secretsmanager:us-east-1:123456789012:secret:example"]
      },
      {
        sid       = "Decrypt"
        actions   = ["kms:Decrypt"]
        resources = ["arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"]
        conditions = [{
          test     = "StringEquals"
          variable = "kms:ViaService"
          values   = ["secretsmanager.us-east-1.amazonaws.com"]
        }]
      },
    ]
  }

  assert {
    condition     = length(data.aws_iam_policy_document.permissions.statement) == 4
    error_message = "Two base statements (logs, network interfaces) plus the two extra ones."
  }
}

run "only_logging_and_network_access_by_default" {
  command = plan

  assert {
    condition     = length(data.aws_iam_policy_document.permissions.statement) == 2
    error_message = "Without extra statements the role may only write logs and manage network interfaces."
  }
}

run "a_missing_package_fails_with_a_clear_message" {
  command = plan

  variables {
    source_dir = "tests/fixtures/not-built"
  }

  expect_failures = [data.archive_file.this]
}

run "rejects_zero_timeout" {
  command = plan

  variables {
    timeout = 0
  }

  expect_failures = [var.timeout]
}

run "rejects_too_little_memory" {
  command = plan

  variables {
    memory_size = 64
  }

  expect_failures = [var.memory_size]
}

run "rejects_negative_concurrency" {
  command = plan

  variables {
    reserved_concurrent_executions = -2
  }

  expect_failures = [var.reserved_concurrent_executions]
}

run "rejects_empty_subnets" {
  command = plan

  variables {
    subnet_ids = []
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_unsupported_log_retention" {
  command = plan

  variables {
    log_retention_days = 10
  }

  expect_failures = [var.log_retention_days]
}
