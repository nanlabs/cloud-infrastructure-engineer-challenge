mock_provider "aws" {
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
}

variables {
  name                    = "info-api-dev"
  cidr_block              = "10.20.0.0/16"
  az_count                = 2
  nat_gateway_mode        = "single"
  flow_log_retention_days = 14
  log_kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
}

run "subnets_follow_the_tier_plan" {
  command = plan

  assert {
    condition     = [for az in ["us-east-1a", "us-east-1b"] : aws_subnet.public[az].cidr_block] == ["10.20.0.0/24", "10.20.1.0/24"]
    error_message = "Public subnets must be 10.20.0.0/24 and 10.20.1.0/24."
  }

  assert {
    condition     = [for az in ["us-east-1a", "us-east-1b"] : aws_subnet.app[az].cidr_block] == ["10.20.10.0/24", "10.20.11.0/24"]
    error_message = "App subnets must be 10.20.10.0/24 and 10.20.11.0/24."
  }

  assert {
    condition     = [for az in ["us-east-1a", "us-east-1b"] : aws_subnet.data[az].cidr_block] == ["10.20.20.0/24", "10.20.21.0/24"]
    error_message = "Data subnets must be 10.20.20.0/24 and 10.20.21.0/24."
  }

  assert {
    condition     = alltrue([for subnet in aws_subnet.public : !subnet.map_public_ip_on_launch])
    error_message = "Public subnets must not hand out public IPs automatically."
  }
}

run "single_mode_shares_one_nat_gateway" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 1 && contains(keys(aws_nat_gateway.this), "us-east-1a")
    error_message = "Single mode must create exactly one NAT gateway, in the first zone."
  }

  assert {
    condition     = length(aws_route.app_nat) == 2
    error_message = "Every app subnet needs its own default route through the NAT gateway."
  }
}

run "nat_gateway_ids_are_exposed_for_alarms" {
  command = plan

  assert {
    condition     = length(output.nat_gateway_ids) == 1
    error_message = "Single mode exposes one NAT gateway ID."
  }
}

run "per_az_mode_creates_one_nat_gateway_per_zone" {
  command = plan

  variables {
    nat_gateway_mode = "per_az"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2 && length(aws_eip.nat) == 2
    error_message = "per_az mode must create one NAT gateway and one address per zone."
  }
}

run "three_zones_scale_every_tier" {
  command = plan

  variables {
    az_count         = 3
    nat_gateway_mode = "per_az"
  }

  assert {
    condition     = length(aws_subnet.public) == 3 && length(aws_subnet.app) == 3 && length(aws_subnet.data) == 3
    error_message = "Each tier must have one subnet per zone."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3
    error_message = "per_az mode must create three NAT gateways for three zones."
  }
}

run "flow_logs_capture_all_traffic_encrypted" {
  command = plan

  assert {
    condition     = aws_flow_log.this.traffic_type == "ALL"
    error_message = "Flow logs must capture accepted and rejected traffic."
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow.retention_in_days == 14 && aws_cloudwatch_log_group.flow.kms_key_id == var.log_kms_key_arn
    error_message = "The flow log group needs the configured retention and the KMS key."
  }
}

run "rejects_single_zone" {
  command = plan

  variables {
    az_count = 1
  }

  expect_failures = [var.az_count]
}

run "rejects_unknown_nat_mode" {
  command = plan

  variables {
    nat_gateway_mode = "none"
  }

  expect_failures = [var.nat_gateway_mode]
}

run "rejects_cidr_too_small_for_the_tiers" {
  command = plan

  variables {
    cidr_block = "10.20.0.0/24"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_unsupported_retention" {
  command = plan

  variables {
    flow_log_retention_days = 10
  }

  expect_failures = [var.flow_log_retention_days]
}
