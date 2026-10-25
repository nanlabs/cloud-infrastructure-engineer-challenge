variable "name" {
  description = "Prefix for key alias names, for example info-api-dev."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "name must be 2-41 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "keys" {
  description = <<-EOT
    Keys to create, by purpose. The key name becomes part of the alias.
    allow_cloudwatch_logs lets CloudWatch Logs encrypt log groups in this account with the key.
    allow_cloudwatch_alarms lets CloudWatch alarms publish to an SNS topic encrypted with the key.
  EOT
  type = map(object({
    description             = string
    allow_cloudwatch_logs   = optional(bool, false)
    allow_cloudwatch_alarms = optional(bool, false)
  }))

  validation {
    condition     = length(var.keys) > 0
    error_message = "keys must define at least one key."
  }
}

variable "deletion_window_in_days" {
  description = "Days a key stays recoverable after it is scheduled for deletion."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}
