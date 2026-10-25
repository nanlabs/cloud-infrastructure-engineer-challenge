variable "name" {
  description = "Prefix for alarm and topic names, for example info-api-dev."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "name must be 2-41 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "kms_key_arn" {
  description = "KMS key that encrypts the alert topic. CloudWatch alarms must be allowed to use it."
  type        = string
}

variable "alert_email" {
  description = "Address that receives alerts. The subscription must be confirmed from the email AWS sends. Null creates the topic without a subscriber."
  type        = string
  default     = null

  validation {
    condition     = var.alert_email == null || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", coalesce(var.alert_email, "")))
    error_message = "alert_email must be null or a valid email address."
  }
}

variable "db_instance_identifier" {
  description = "RDS instance to watch."
  type        = string
}

variable "db_connections_threshold" {
  description = "Connection count that raises an alarm. Set it near 75% of max_connections for the instance class."
  type        = number
  default     = 60

  validation {
    condition     = var.db_connections_threshold >= 1
    error_message = "db_connections_threshold must be at least 1."
  }
}

variable "lambda_function_name" {
  description = "Lambda function to watch."
  type        = string
}

variable "lambda_timeout_seconds" {
  description = "Timeout of the function. The duration alarm fires at 80% of it."
  type        = number

  validation {
    condition     = var.lambda_timeout_seconds >= 1
    error_message = "lambda_timeout_seconds must be at least 1."
  }
}

variable "lambda_log_group_name" {
  description = "Log group the saved queries search for the function."
  type        = string
}

variable "api_id" {
  description = "HTTP API to watch."
  type        = string
}

variable "api_access_log_group_name" {
  description = "Log group the saved query searches for API latency."
  type        = string
}

variable "nat_gateway_ids" {
  description = "NAT gateways to watch for port exhaustion."
  type        = list(string)

  validation {
    condition     = length(var.nat_gateway_ids) >= 1
    error_message = "nat_gateway_ids must contain at least one NAT gateway."
  }
}
