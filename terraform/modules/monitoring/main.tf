locals {
  # An empty string means "not used": every entry has the same shape so they can
  # live in one map.
  alarms = merge(
    {
      "rds-cpu-high" = {
        description        = "Database CPU above 80% for 15 minutes"
        namespace          = "AWS/RDS"
        metric_name        = "CPUUtilization"
        dimensions         = { DBInstanceIdentifier = var.db_instance_identifier }
        statistic          = "Average"
        extended_statistic = ""
        period             = 300
        evaluation_periods = 3
        threshold          = 80
        comparison         = "GreaterThanThreshold"
      }
      "rds-storage-low" = {
        description        = "Database free storage below 2 GiB"
        namespace          = "AWS/RDS"
        metric_name        = "FreeStorageSpace"
        dimensions         = { DBInstanceIdentifier = var.db_instance_identifier }
        statistic          = "Minimum"
        extended_statistic = ""
        period             = 300
        evaluation_periods = 1
        threshold          = 2147483648
        comparison         = "LessThanThreshold"
      }
      "rds-memory-low" = {
        description        = "Database freeable memory below 64 MiB for 15 minutes"
        namespace          = "AWS/RDS"
        metric_name        = "FreeableMemory"
        dimensions         = { DBInstanceIdentifier = var.db_instance_identifier }
        statistic          = "Minimum"
        extended_statistic = ""
        period             = 300
        evaluation_periods = 3
        threshold          = 67108864
        comparison         = "LessThanThreshold"
      }
      "rds-connections-high" = {
        description        = "Database connections above ${var.db_connections_threshold}, close to the limit"
        namespace          = "AWS/RDS"
        metric_name        = "DatabaseConnections"
        dimensions         = { DBInstanceIdentifier = var.db_instance_identifier }
        statistic          = "Maximum"
        extended_statistic = ""
        period             = 300
        evaluation_periods = 2
        threshold          = var.db_connections_threshold
        comparison         = "GreaterThanThreshold"
      }
      "lambda-errors" = {
        description        = "The function returned an error"
        namespace          = "AWS/Lambda"
        metric_name        = "Errors"
        dimensions         = { FunctionName = var.lambda_function_name }
        statistic          = "Sum"
        extended_statistic = ""
        period             = 300
        evaluation_periods = 1
        threshold          = 1
        comparison         = "GreaterThanOrEqualToThreshold"
      }
      "lambda-throttles" = {
        description        = "Requests were rejected because the concurrency cap was reached"
        namespace          = "AWS/Lambda"
        metric_name        = "Throttles"
        dimensions         = { FunctionName = var.lambda_function_name }
        statistic          = "Sum"
        extended_statistic = ""
        period             = 300
        evaluation_periods = 1
        threshold          = 1
        comparison         = "GreaterThanOrEqualToThreshold"
      }
      "lambda-duration-p99" = {
        description        = "p99 duration above 80% of the function timeout for 15 minutes"
        namespace          = "AWS/Lambda"
        metric_name        = "Duration"
        dimensions         = { FunctionName = var.lambda_function_name }
        statistic          = ""
        extended_statistic = "p99"
        period             = 300
        evaluation_periods = 3
        threshold          = var.lambda_timeout_seconds * 800
        comparison         = "GreaterThanThreshold"
      }
      "api-5xx" = {
        description        = "The API returned server errors"
        namespace          = "AWS/ApiGateway"
        metric_name        = "5xx"
        dimensions         = { ApiId = var.api_id }
        statistic          = "Sum"
        extended_statistic = ""
        period             = 300
        evaluation_periods = 1
        threshold          = 1
        comparison         = "GreaterThanOrEqualToThreshold"
      }
    },
    {
      # Keyed by position: the IDs only exist after apply, and for_each keys
      # must be known at plan time.
      for index, id in var.nat_gateway_ids : "nat-port-allocation-${index + 1}" => {
        description        = "NAT gateway ${id} ran out of source ports: too many concurrent connections"
        namespace          = "AWS/NATGateway"
        metric_name        = "ErrorPortAllocation"
        dimensions         = { NatGatewayId = id }
        statistic          = "Sum"
        extended_statistic = ""
        period             = 300
        evaluation_periods = 1
        threshold          = 0
        comparison         = "GreaterThanThreshold"
      }
    },
  )
}

resource "aws_sns_topic" "alerts" {
  name              = "${var.name}-alerts"
  kms_master_key_id = var.kms_key_arn
}

resource "aws_sns_topic_subscription" "email" {
  for_each = var.alert_email == null ? toset([]) : toset([var.alert_email])

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.alarms

  alarm_name          = "${var.name}-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric_name
  dimensions          = each.value.dimensions
  statistic           = each.value.statistic == "" ? null : each.value.statistic
  extended_statistic  = each.value.extended_statistic == "" ? null : each.value.extended_statistic
  period              = each.value.period
  evaluation_periods  = each.value.evaluation_periods
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison

  # A quiet system emits no data points; that is not a failure.
  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_query_definition" "recent_problems" {
  name            = "${var.name}/recent-warnings-and-errors"
  log_group_names = [var.lambda_log_group_name]

  query_string = <<-EOT
    fields @timestamp, level, message, request_id
    | filter level in ["WARN", "WARNING", "ERROR", "CRITICAL", "FATAL"]
    | sort @timestamp desc
    | limit 50
  EOT
}

resource "aws_cloudwatch_query_definition" "database_failures" {
  name            = "${var.name}/database-failures-by-category"
  log_group_names = [var.lambda_log_group_name]

  query_string = <<-EOT
    fields @timestamp, category
    | filter message = "database unavailable"
    | stats count() as failures by category, bin(5m)
    | sort @timestamp desc
  EOT
}

resource "aws_cloudwatch_query_definition" "api_latency" {
  name            = "${var.name}/api-latency-percentiles"
  log_group_names = [var.api_access_log_group_name]

  # jsonencode quotes $context.responseLatency as a string; parse extracts a number for avg/pct.
  query_string = <<-EOT
    parse responseLatency /^(?<latency_ms>\d+)$/
    | stats count() as requests, avg(latency_ms) as avg_ms, pct(latency_ms, 99) as p99_ms by bin(5m)
    | sort @timestamp desc
  EOT
}
