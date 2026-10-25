variable "name" {
  description = "Prefix for security group names, for example info-api-dev."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "name must be 2-41 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "vpc_id" {
  description = "VPC the security groups belong to."
  type        = string
}

variable "db_port" {
  description = "TCP port the database listens on."
  type        = number
  default     = 5432

  validation {
    condition     = var.db_port >= 1024 && var.db_port <= 65535
    error_message = "db_port must be between 1024 and 65535."
  }
}
