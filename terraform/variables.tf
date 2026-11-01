variable "aws_region" {
  description = "AWS region where all resources are deployed."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name, used as prefix for resource names and as a tag."
  type        = string
  default     = "nanlabs-challenge"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.project))
    error_message = "project must be 3-24 characters: lowercase letters, numbers and hyphens."
  }
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.environment))
    error_message = "environment must be 2-10 lowercase alphanumeric characters."
  }
}

variable "log_retention_days" {
  description = "Retention in days for every CloudWatch log group created by this stack."
  type        = number
  default     = 14
}

################################################################################
# Network
################################################################################

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones (2 or 3)."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT Gateway (cost) instead of one per AZ (availability)."
  type        = bool
  default     = true
}

################################################################################
# Database
################################################################################

variable "db_engine_version" {
  description = "PostgreSQL version (major only lets RDS pick the latest default minor)."
  type        = string
  default     = "17"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_multi_az" {
  description = "Run RDS Multi-AZ (synchronous standby + automatic failover)."
  type        = bool
  default     = true
}

variable "db_backup_retention_days" {
  description = "Days to keep automated RDS backups (point-in-time recovery window)."
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Protect the RDS instance from deletion. Set to true outside of disposable environments."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot on destroy (false keeps a \"<name>-final\" snapshot)."
  type        = bool
  default     = false
}

################################################################################
# API
################################################################################

variable "api_throttling_rate_limit" {
  description = "Steady-state requests per second allowed by API Gateway."
  type        = number
  default     = 10
}

variable "api_throttling_burst_limit" {
  description = "Maximum request burst allowed by API Gateway."
  type        = number
  default     = 20
}

################################################################################
# Monitoring
################################################################################

variable "alarm_email" {
  description = "Email notified by the CloudWatch alarms (confirm the subscription email). null = no notifications."
  type        = string
  default     = null
}
