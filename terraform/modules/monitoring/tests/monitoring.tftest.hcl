mock_provider "aws" {
  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-east-1:123456789012:info-api-dev-alerts"
    }
  }
}

variables {
  name                      = "info-api-dev"
  kms_key_arn               = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222"
  db_instance_identifier    = "info-api-dev-db"
  lambda_function_name      = "info-api-dev-info"
  lambda_timeout_seconds    = 15
  lambda_log_group_name     = "/aws/lambda/info-api-dev-info"
  api_id                    = "abc123defg"
  api_access_log_group_name = "/aws/apigateway/info-api-dev-info/access"
  nat_gateway_ids           = ["nat-0aaaaaaaaaaaaaaaa"]
}

run "every_signal_has_an_alarm" {
  command = plan

  assert {
    condition = toset(keys(aws_cloudwatch_metric_alarm.this)) == toset([
      "rds-cpu-high",
      "rds-storage-low",
      "rds-memory-low",
      "rds-connections-high",
      "lambda-errors",
      "lambda-throttles",
      "lambda-duration-p99",
      "api-5xx",
      "nat-port-allocation-1",
    ])
    error_message = "Expected the database, Lambda, API and NAT alarms."
  }
}

run "there_is_one_nat_alarm_per_gateway" {
  command = plan

  variables {
    nat_gateway_ids = ["nat-0aaaaaaaaaaaaaaaa", "nat-0bbbbbbbbbbbbbbbb"]
  }

  assert {
    condition     = length([for key in keys(aws_cloudwatch_metric_alarm.this) : key if startswith(key, "nat-port-allocation-")]) == 2
    error_message = "Each NAT gateway needs its own alarm."
  }
}

run "alarms_watch_the_right_resources" {
  command = plan

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.this["rds-cpu-high"].dimensions["DBInstanceIdentifier"] == "info-api-dev-db" &&
      aws_cloudwatch_metric_alarm.this["lambda-errors"].dimensions["FunctionName"] == "info-api-dev-info" &&
      aws_cloudwatch_metric_alarm.this["api-5xx"].dimensions["ApiId"] == "abc123defg" &&
      aws_cloudwatch_metric_alarm.this["nat-port-allocation-1"].dimensions["NatGatewayId"] == "nat-0aaaaaaaaaaaaaaaa"
    )
    error_message = "Each alarm must use the dimension of the resource it watches."
  }
}

run "thresholds_follow_the_design" {
  command = plan

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.this["rds-cpu-high"].threshold == 80 &&
      aws_cloudwatch_metric_alarm.this["rds-storage-low"].threshold == 2147483648 &&
      aws_cloudwatch_metric_alarm.this["rds-memory-low"].threshold == 67108864 &&
      aws_cloudwatch_metric_alarm.this["rds-connections-high"].threshold == 60
    )
    error_message = "Database thresholds must match the documented values."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.this["lambda-duration-p99"].threshold == 12000 &&
      aws_cloudwatch_metric_alarm.this["lambda-duration-p99"].extended_statistic == "p99" &&
      aws_cloudwatch_metric_alarm.this["lambda-duration-p99"].statistic == null
    )
    error_message = "The duration alarm must fire at 80% of a 15 s timeout, on the p99."
  }
}

run "duration_threshold_follows_the_timeout" {
  command = plan

  variables {
    lambda_timeout_seconds = 30
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["lambda-duration-p99"].threshold == 24000
    error_message = "The duration threshold must be 80% of the configured timeout."
  }
}

run "connection_threshold_is_configurable" {
  command = plan

  variables {
    db_connections_threshold = 200
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["rds-connections-high"].threshold == 200
    error_message = "The connection threshold must follow the input."
  }
}

run "every_alarm_notifies_on_alarm_and_recovery_and_quiet_is_ok" {
  command = apply

  assert {
    condition = alltrue([
      for alarm in aws_cloudwatch_metric_alarm.this :
      alarm.alarm_actions == toset([aws_sns_topic.alerts.arn]) &&
      alarm.ok_actions == toset([aws_sns_topic.alerts.arn]) &&
      alarm.treat_missing_data == "notBreaching"
    ])
    error_message = "Alarms and recoveries must go to the topic, and missing data must not count as a breach."
  }
}

run "the_topic_is_encrypted_with_the_given_key" {
  command = plan

  assert {
    condition     = aws_sns_topic.alerts.kms_master_key_id == var.kms_key_arn
    error_message = "The alert topic must use the observability key."
  }
}

run "no_subscriber_without_an_email" {
  command = plan

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 0
    error_message = "Without alert_email there must be no subscription."
  }
}

run "an_email_creates_one_subscription" {
  command = plan

  variables {
    alert_email = "oncall@example.com"
  }

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 1 && aws_sns_topic_subscription.email["oncall@example.com"].protocol == "email"
    error_message = "alert_email must create one email subscription."
  }
}

run "saved_queries_search_the_right_log_groups" {
  command = plan

  assert {
    condition = (
      aws_cloudwatch_query_definition.recent_problems.log_group_names == tolist(["/aws/lambda/info-api-dev-info"]) &&
      aws_cloudwatch_query_definition.database_failures.log_group_names == tolist(["/aws/lambda/info-api-dev-info"]) &&
      aws_cloudwatch_query_definition.api_latency.log_group_names == tolist(["/aws/apigateway/info-api-dev-info/access"])
    )
    error_message = "Function queries search the function log group; the latency query searches the API access log group."
  }

  assert {
    condition     = can(regex("parse responseLatency", aws_cloudwatch_query_definition.api_latency.query_string))
    error_message = "responseLatency is logged as a JSON string, so the query must parse it as a number before avg/pct."
  }
}

run "rejects_a_malformed_email" {
  command = plan

  variables {
    alert_email = "not-an-email"
  }

  expect_failures = [var.alert_email]
}

run "rejects_no_nat_gateways" {
  command = plan

  variables {
    nat_gateway_ids = []
  }

  expect_failures = [var.nat_gateway_ids]
}

run "rejects_a_zero_timeout" {
  command = plan

  variables {
    lambda_timeout_seconds = 0
  }

  expect_failures = [var.lambda_timeout_seconds]
}
