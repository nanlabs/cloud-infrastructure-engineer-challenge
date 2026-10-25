variable "name" {
  description = "Function name. Also names the IAM role and the log group."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-_]{1,63}$", var.name))
    error_message = "name must be 2-64 characters: letters, digits, hyphens and underscores, starting with a letter."
  }
}

variable "source_dir" {
  description = "Directory holding the built package (code and dependencies). Created by make build."
  type        = string
}

variable "handler" {
  description = "Handler in module.function form. The module path decides which file must exist in source_dir."
  type        = string
  default     = "info_api.handler.lambda_handler"
}

variable "runtime" {
  description = "Lambda runtime."
  type        = string
  default     = "python3.13"
}

variable "memory_size" {
  description = "Memory in MB. CPU scales with it."
  type        = number
  default     = 256

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be between 128 and 10240."
  }
}

variable "timeout" {
  description = "Function timeout in seconds. Keep it below the API integration timeout."
  type        = number
  default     = 15

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout must be between 1 and 900 seconds."
  }
}

variable "reserved_concurrent_executions" {
  description = "Cap on concurrent executions, which also caps database connections. -1 leaves it unreserved."
  type        = number
  default     = -1

  validation {
    condition     = var.reserved_concurrent_executions >= -1
    error_message = "reserved_concurrent_executions must be -1 (unreserved) or zero or more."
  }
}

variable "subnet_ids" {
  description = "Private subnets the function's network interfaces are placed in."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "subnet_ids must contain at least one subnet."
  }
}

variable "security_group_id" {
  description = "Security group attached to the function's network interfaces."
  type        = string
}

variable "environment" {
  description = "Environment variables. Must not hold secrets."
  type        = map(string)
  default     = {}
}

variable "policy_statements" {
  description = "Extra IAM statements for the execution role, on top of logging and network access."
  type = list(object({
    sid       = string
    actions   = list(string)
    resources = list(string)
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = []
}

variable "log_retention_days" {
  description = "Days to keep the function's logs. Must be a retention value CloudWatch Logs accepts."
  type        = number

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a retention value CloudWatch Logs accepts, for example 7, 14, 30 or 90."
  }
}

variable "log_kms_key_arn" {
  description = "KMS key that encrypts the log group. CloudWatch Logs must be allowed to use it."
  type        = string
}
