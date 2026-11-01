variable "name" {
  description = "Name prefix for the alarms and the SNS topic."
  type        = string
}

variable "alarm_email" {
  description = "Email subscribed to the alarms topic (AWS sends a confirmation link). null = no subscription."
  type        = string
  default     = null
}

variable "db_instance_id" {
  description = "RDS instance identifier to monitor."
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function to monitor."
  type        = string
}

variable "api_id" {
  description = "HTTP API ID to monitor."
  type        = string
}

variable "api_stage" {
  description = "HTTP API stage to monitor."
  type        = string
}

variable "rds_cpu_threshold_percent" {
  description = "RDS CPU alarm threshold (%)."
  type        = number
  default     = 80
}

variable "rds_free_storage_threshold_gib" {
  description = "RDS free storage alarm threshold (GiB)."
  type        = number
  default     = 2
}

variable "rds_connections_threshold" {
  description = "RDS connections alarm threshold."
  type        = number
  default     = 50
}
