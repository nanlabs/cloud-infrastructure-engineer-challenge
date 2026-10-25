variable "project" {
  description = "Short project name used as the prefix of every resource name."
  type        = string
  default     = "info-api-extended"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.project))
    error_message = "project must be 2-20 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment. Selects the settings profile in environments/<env>/."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "region" {
  description = "AWS region to deploy into, for example us-east-1."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "region must look like us-east-1."
  }
}

variable "owner" {
  description = "Owner tag applied to every resource."
  type        = string
}

variable "allowed_account_ids" {
  description = "AWS account IDs Terraform may run against. Leave empty to disable the guard."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.allowed_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "Each account ID must be exactly 12 digits."
  }
}

variable "kms_deletion_window_in_days" {
  description = "Days a KMS key stays recoverable after deletion is scheduled (7-30)."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "vpc_cidr_block" {
  description = "IPv4 CIDR of the VPC. Subnets are /24 blocks carved from it, so use /16 or larger."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across (2 or 3)."
  type        = number
  default     = 2
}

variable "nat_gateway_mode" {
  description = "single shares one NAT gateway across zones (cheaper). per_az gives each zone its own, so one zone failing does not cut egress for the others."
  type        = string
}

variable "flow_log_retention_days" {
  description = "Days to keep VPC flow logs."
  type        = number
}

variable "log_retention_days" {
  description = "Days to keep CloudWatch log groups other than VPC flow logs."
  type        = number
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial database storage in GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Ceiling in GiB that database storage grows to automatically."
  type        = number
  default     = 50
}

variable "db_multi_az" {
  description = "Run a synchronous standby in a second zone with automatic failover."
  type        = bool
}

variable "db_backup_retention_days" {
  description = "Days to keep automated database backups (1-35). Sets the point-in-time restore window."
  type        = number
}

variable "db_deletion_protection" {
  description = "Refuse to delete the database while true."
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip the snapshot taken when the database is deleted. Leave false anywhere data matters."
  type        = bool
  default     = false
}

variable "db_apply_immediately" {
  description = "Apply database modifications now instead of in the next maintenance window. Some changes restart the database."
  type        = bool
  default     = false
}

variable "lambda_package_dir" {
  description = "Directory holding the built Lambda package. Created by make build."
  type        = string
  default     = "../build/functions/info"
}

variable "lambda_reserved_concurrency" {
  description = "Cap on concurrent Lambda executions, which also caps database connections. -1 leaves it unreserved; accounts with a low concurrency quota cannot reserve any."
  type        = number
  default     = -1
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout (3-29 seconds). API Gateway waits one second longer, so callers see the function's own error rather than a gateway timeout."
  type        = number
  default     = 15

  validation {
    condition     = var.lambda_timeout_seconds >= 3 && var.lambda_timeout_seconds <= 29
    error_message = "lambda_timeout_seconds must be between 3 and 29 seconds so integration_timeout_ms stays within API Gateway HTTP API's 30000 ms limit."
  }
}

variable "api_throttling_rate_limit" {
  description = "Requests per second the API accepts. Excess requests get HTTP 429 before they reach the database."
  type        = number
}

variable "api_throttling_burst_limit" {
  description = "Short burst of requests the API accepts above the steady rate."
  type        = number
}

variable "alert_email" {
  description = "Address that receives alarm notifications. AWS emails a confirmation link that must be clicked. Null creates the topic without a subscriber."
  type        = string
  default     = null
}

variable "db_connections_alarm_threshold" {
  description = "Database connection count that raises an alarm: about 75% of max_connections. The default of 60 suits db.t4g.micro and must be revisited with the instance class."
  type        = number
  default     = 60
}
