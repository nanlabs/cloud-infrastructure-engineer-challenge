variable "name" {
  description = "Prefix for resource names, for example info-api-dev. The instance identifier is <name>-db."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "name must be 2-41 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "subnet_ids" {
  description = "Isolated subnets for the database, in at least two availability zones."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids must contain at least two subnets in different availability zones."
  }
}

variable "security_group_id" {
  description = "Security group attached to the database."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key that encrypts the database storage and the master password secret."
  type        = string
}

variable "log_kms_key_arn" {
  description = "KMS key that encrypts the database log groups. CloudWatch Logs must be allowed to use it."
  type        = string
}

variable "postgres_major_version" {
  description = "PostgreSQL major version. RDS picks the minor version and upgrades it automatically."
  type        = string
  default     = "17"

  validation {
    condition     = can(regex("^[0-9]{2}$", var.postgres_major_version))
    error_message = "postgres_major_version must be a two-digit major version such as 17."
  }
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"

  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.instance_class))
    error_message = "instance_class must look like db.t4g.micro."
  }
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GiB."
  }
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB. Must be larger than allocated_storage."
  type        = number
  default     = 50

  validation {
    condition     = var.max_allocated_storage > var.allocated_storage
    error_message = "max_allocated_storage must be larger than allocated_storage."
  }
}

variable "multi_az" {
  description = "Keep a synchronous standby in a second zone and fail over automatically."
  type        = bool
}

variable "backup_retention_days" {
  description = "Days to keep automated backups. Also sets the point-in-time restore window."
  type        = number

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "backup_window" {
  description = "Daily UTC window for automated backups. Must not overlap maintenance_window."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly UTC window for maintenance. Must not overlap backup_window."
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "deletion_protection" {
  description = "Refuse to delete the instance while true."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the snapshot taken when the instance is deleted. Leave false anywhere data matters."
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Apply modifications now instead of in the next maintenance window. Some changes cause a restart."
  type        = bool
  default     = false
}

variable "port" {
  description = "TCP port the database listens on."
  type        = number
  default     = 5432
}

variable "database_name" {
  description = "Name of the initial database."
  type        = string
  default     = "appdb"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.database_name))
    error_message = "database_name must start with a lowercase letter and contain only lowercase letters, digits and underscores."
  }
}

variable "master_username" {
  description = "Master user name. The password is generated and stored by RDS in Secrets Manager."
  type        = string
  default     = "dbadmin"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,15}$", var.master_username)) && !contains(["postgres", "rdsadmin"], var.master_username)
    error_message = "master_username must start with a lowercase letter, be at most 16 characters, and not be postgres or rdsadmin."
  }
}

variable "log_retention_days" {
  description = "Days to keep the database log groups. Must be a retention value CloudWatch Logs accepts."
  type        = number

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a retention value CloudWatch Logs accepts, for example 7, 14, 30 or 90."
  }
}
