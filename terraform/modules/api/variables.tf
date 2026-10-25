variable "name" {
  description = "Name of the API. Also names the access log group."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-_]{1,63}$", var.name))
    error_message = "name must be 2-64 characters: letters, digits, hyphens and underscores, starting with a letter."
  }
}

variable "lambda_function_name" {
  description = "Function API Gateway is allowed to invoke."
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the function."
  type        = string
}

variable "route_key" {
  description = "HTTP method and path served by the function, for example GET /info."
  type        = string
  default     = "GET /info"

  validation {
    condition     = can(regex("^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS) /[A-Za-z0-9/_-]*$", var.route_key))
    error_message = "route_key must be an HTTP method and an absolute path without variables, for example GET /info."
  }
}

variable "integration_timeout_ms" {
  description = "How long API Gateway waits for the function. Keep it above the function timeout so the function's own error is what callers see. HTTP APIs allow at most 30000."
  type        = number
  default     = 16000

  validation {
    condition     = var.integration_timeout_ms >= 50 && var.integration_timeout_ms <= 30000
    error_message = "integration_timeout_ms must be between 50 and 30000."
  }
}

variable "throttling_rate_limit" {
  description = "Steady-state requests per second the stage accepts. Excess requests get HTTP 429."
  type        = number

  validation {
    condition     = var.throttling_rate_limit >= 1
    error_message = "throttling_rate_limit must be at least 1."
  }
}

variable "throttling_burst_limit" {
  description = "Short burst of requests the stage accepts above the steady rate."
  type        = number

  validation {
    condition     = var.throttling_burst_limit >= 1
    error_message = "throttling_burst_limit must be at least 1."
  }
}

variable "log_retention_days" {
  description = "Days to keep access logs. Must be a retention value CloudWatch Logs accepts."
  type        = number

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a retention value CloudWatch Logs accepts, for example 7, 14, 30 or 90."
  }
}

variable "log_kms_key_arn" {
  description = "KMS key that encrypts the access log group. CloudWatch Logs must be allowed to use it."
  type        = string
}
