output "topic_arn" {
  description = "SNS topic that receives every alarm and recovery."
  value       = aws_sns_topic.alerts.arn
}

output "alarm_names" {
  description = "Names of all alarms, sorted."
  value       = sort([for alarm in aws_cloudwatch_metric_alarm.this : alarm.alarm_name])
}
