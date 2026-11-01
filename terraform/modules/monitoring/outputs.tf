output "sns_topic_arn" {
  description = "SNS topic receiving all alarm notifications."
  value       = aws_sns_topic.alarms.arn
}
