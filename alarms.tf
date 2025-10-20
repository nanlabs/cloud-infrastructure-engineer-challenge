# alarma para CPU
# evaluation periods breves para probar la alarma
resource "aws_cloudwatch_metric_alarm" "rds_cpu_usage_high" {
  alarm_name                = "rds_cpu_alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/RDS"
  period                    = 60
  statistic                 = "Average"
  threshold                 = 90
  alarm_description         = "Trigger alarm if CPU usage is above 90%."
  alarm_actions             = [aws_sns_topic.rds_alarms_topic.arn]
  ok_actions                = [aws_sns_topic.rds_alarms_topic.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.nanlabs-rds.identifier
  }
}

# alarma para memoria
# evaluation periods breves para probar la alarma
resource "aws_cloudwatch_metric_alarm" "rds_memory_low" {
  alarm_name                = "rds_low_freeable_memory"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 1
  metric_name               = "FreeableMemory"
  namespace                 = "AWS/RDS"
  period                    = 60
  statistic                 = "Average"
  
  # umbral en bytes 100mb
  threshold                 = 104857600
  
  alarm_description         = "Trigger alarm if RDS freeable memory drops below 100 MB."
  actions_enabled           = true
  alarm_actions             = [aws_sns_topic.rds_alarms_topic.arn]
  ok_actions                = [aws_sns_topic.rds_alarms_topic.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.nanlabs-rds.identifier
  }
}

# alarma para storage
# evaluation periods breves para probar la alarma
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name                = "rds_low_storage"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 1
  metric_name               = "FreeStorageSpace"
  namespace                 = "AWS/RDS"
  period                    = 60
  statistic                 = "Average"
  
  # umbral en bytes, 1gb
  threshold                 = 1073741824 
  
  alarm_description         = "Trigger alarm if RDS free storage space drops below 1 GB."
  actions_enabled           = true
  alarm_actions             = [aws_sns_topic.rds_alarms_topic.arn]
  ok_actions                = [aws_sns_topic.rds_alarms_topic.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.nanlabs-rds.identifier
  }
}