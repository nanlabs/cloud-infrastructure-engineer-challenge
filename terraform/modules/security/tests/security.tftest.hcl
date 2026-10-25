mock_provider "aws" {}

variables {
  name   = "info-api-dev"
  vpc_id = "vpc-0123456789abcdef0"
}

run "database_accepts_only_the_lambda_security_group" {
  command = apply

  assert {
    condition     = aws_vpc_security_group_ingress_rule.database_from_lambda.referenced_security_group_id == aws_security_group.lambda.id
    error_message = "The database must accept connections only from the Lambda security group."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.database_from_lambda.cidr_ipv4 == null &&
      aws_vpc_security_group_ingress_rule.database_from_lambda.cidr_ipv6 == null
    )
    error_message = "The database ingress rule must not use any CIDR range."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.database_from_lambda.from_port == 5432 &&
      aws_vpc_security_group_ingress_rule.database_from_lambda.to_port == 5432 &&
      aws_vpc_security_group_ingress_rule.database_from_lambda.ip_protocol == "tcp"
    )
    error_message = "Only TCP 5432 may reach the database."
  }
}

run "lambda_egress_is_limited_to_the_database_and_https" {
  command = apply

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.lambda_to_database.referenced_security_group_id == aws_security_group.database.id &&
      aws_vpc_security_group_egress_rule.lambda_to_database.from_port == 5432 &&
      aws_vpc_security_group_egress_rule.lambda_to_database.to_port == 5432
    )
    error_message = "Lambda may reach the database only on its port, by security group."
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.lambda_to_aws_apis.from_port == 443 &&
      aws_vpc_security_group_egress_rule.lambda_to_aws_apis.to_port == 443 &&
      aws_vpc_security_group_egress_rule.lambda_to_aws_apis.ip_protocol == "tcp"
    )
    error_message = "The only other Lambda egress is HTTPS."
  }
}

run "custom_database_port_applies_to_both_sides" {
  command = plan

  variables {
    db_port = 5433
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.database_from_lambda.from_port == 5433 &&
      aws_vpc_security_group_egress_rule.lambda_to_database.to_port == 5433
    )
    error_message = "The ingress and egress rules must use the configured port."
  }
}

run "rejects_privileged_database_port" {
  command = plan

  variables {
    db_port = 80
  }

  expect_failures = [var.db_port]
}

run "rejects_invalid_name" {
  command = plan

  variables {
    name = "Bad Name"
  }

  expect_failures = [var.name]
}
