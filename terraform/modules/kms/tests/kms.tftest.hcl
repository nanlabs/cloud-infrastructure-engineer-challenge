mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name = "info-api-dev"
  keys = {
    data = {
      description = "data key"
    }
    observability = {
      description             = "logs and alarms key"
      allow_cloudwatch_logs   = true
      allow_cloudwatch_alarms = true
    }
  }
}

run "keys_rotate_and_are_aliased" {
  command = plan

  assert {
    condition     = alltrue([for key in aws_kms_key.this : key.enable_key_rotation])
    error_message = "Every key must have rotation enabled."
  }

  assert {
    condition     = aws_kms_alias.this["data"].name == "alias/info-api-dev-data"
    error_message = "Alias must be alias/<name>-<key>."
  }

  assert {
    condition     = length(aws_kms_key.this) == 2
    error_message = "One key per entry in the keys input."
  }
}

run "service_access_is_opt_in" {
  command = plan

  assert {
    condition     = length(data.aws_iam_policy_document.this["data"].statement) == 1
    error_message = "A key without service access has only the account statement."
  }

  assert {
    condition     = length(data.aws_iam_policy_document.this["observability"].statement) == 3
    error_message = "The observability key adds the logs and alarms statements."
  }
}

run "rejects_short_deletion_window" {
  command = plan

  variables {
    deletion_window_in_days = 3
  }

  expect_failures = [var.deletion_window_in_days]
}

run "rejects_empty_keys" {
  command = plan

  variables {
    keys = {}
  }

  expect_failures = [var.keys]
}

run "rejects_invalid_name" {
  command = plan

  variables {
    name = "Bad Name"
  }

  expect_failures = [var.name]
}
