variable "name" {
  description = "Identifier of the RDS instance; also used as prefix for related resources."
  type        = string
}

variable "subnet_ids" {
  description = "Database subnet IDs (at least two AZs)."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS requires subnets in at least two Availability Zones."
  }
}

variable "security_group_ids" {
  description = "Security groups attached to the RDS instance."
  type        = list(string)
}

variable "engine_version" {
  description = "PostgreSQL version. A major version (e.g. \"17\") lets RDS pick the latest default minor."
  type        = string
  default     = "17"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "database_name" {
  description = "Name of the initial database."
  type        = string
  default     = "app"
}

variable "master_username" {
  description = "Master username. The password is generated and managed by RDS in Secrets Manager."
  type        = string
  default     = "dbadmin"
}

variable "port" {
  description = "Port PostgreSQL listens on."
  type        = number
  default     = 5432
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit in GiB for storage autoscaling."
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Keep a synchronous standby in another AZ with automatic failover."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Days to keep automated backups (enables point-in-time recovery)."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35 (0 would disable backups)."
  }
}

variable "deletion_protection" {
  description = "Block deletion of the instance. Recommended true for production."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when the instance is destroyed."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Retention in days for the exported PostgreSQL logs."
  type        = number
  default     = 14
}
