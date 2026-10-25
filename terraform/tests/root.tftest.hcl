# Run once per environment, so each tfvars file is exercised as shipped:
#   terraform test -var-file=environments/dev/terraform.tfvars

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

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/mock"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      arn = "arn:aws:rds:us-east-1:123456789012:db:mock"
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!db-mock"
        kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
        secret_status = "active"
      }]
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn        = "arn:aws:lambda:us-east-1:123456789012:function:mock"
      invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:mock/invocations"
    }
  }

  mock_resource "aws_apigatewayv2_api" {
    defaults = {
      id            = "abc123defg"
      api_endpoint  = "https://abc123defg.execute-api.us-east-1.amazonaws.com"
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:abc123defg"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-east-1:123456789012:mock-alerts"
    }
  }
}

variables {
  lambda_package_dir = "modules/lambda/tests/fixtures/package"
}

run "the_environment_deploys_one_consistent_stack" {
  command = apply

  assert {
    condition     = output.database_identifier == "info-api-extended-${var.environment}-db"
    error_message = "Resource names must carry the project and environment."
  }

  assert {
    condition     = output.lambda_function_name == "info-api-extended-${var.environment}-info"
    error_message = "The function name must carry the project and environment."
  }

  assert {
    condition     = output.info_url == "https://abc123defg.execute-api.us-east-1.amazonaws.com/info"
    error_message = "The published URL must be the API endpoint plus /info."
  }

  assert {
    condition     = output.region == var.region && output.account_id == "123456789012"
    error_message = "The target account and region must be reported."
  }
}

run "nat_layout_matches_the_environment" {
  command = apply

  assert {
    condition     = length(output.nat_public_ips) == (var.environment == "prod" ? 2 : 1)
    error_message = "Prod needs one NAT gateway per zone; dev shares one."
  }
}

run "an_unknown_environment_is_rejected" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "a_malformed_account_id_is_rejected" {
  command = plan

  variables {
    allowed_account_ids = ["1234"]
  }

  expect_failures = [var.allowed_account_ids]
}

run "a_lambda_timeout_over_29_seconds_is_rejected" {
  command = plan

  variables {
    lambda_timeout_seconds = 30
  }

  expect_failures = [var.lambda_timeout_seconds]
}
