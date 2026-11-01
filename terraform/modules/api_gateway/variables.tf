variable "name" {
  description = "Name of the HTTP API."
  type        = string
}

variable "description" {
  description = "Description of the HTTP API."
  type        = string
  default     = ""
}

variable "lambda_function_name" {
  description = "Name of the Lambda function behind GET /info."
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function behind GET /info."
  type        = string
}

variable "throttling_rate_limit" {
  description = "Steady-state requests per second allowed."
  type        = number
  default     = 10
}

variable "throttling_burst_limit" {
  description = "Maximum concurrent request burst allowed."
  type        = number
  default     = 20
}

variable "log_retention_days" {
  description = "Retention in days for the access logs."
  type        = number
  default     = 14
}
