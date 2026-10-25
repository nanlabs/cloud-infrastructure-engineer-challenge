variable "name" {
  description = "Prefix for resource names, for example info-api-dev."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "name must be 2-41 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "cidr_block" {
  description = "IPv4 CIDR of the VPC. Each subnet is a /24 carved from it, so the prefix must be /16 or larger."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) && try(tonumber(split("/", var.cidr_block)[1]) <= 16, false)
    error_message = "cidr_block must be a valid IPv4 CIDR with a prefix length of /16 or shorter."
  }
}

variable "az_count" {
  description = "Number of availability zones to use. Each gets one subnet per tier."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "nat_gateway_mode" {
  description = "single shares one NAT gateway (cheaper, one zone is a single point of failure). per_az gives each zone its own."
  type        = string

  validation {
    condition     = contains(["single", "per_az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be single or per_az."
  }
}

variable "flow_log_retention_days" {
  description = "Days to keep VPC flow logs. Must be a retention value CloudWatch Logs accepts."
  type        = number

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_log_retention_days)
    error_message = "flow_log_retention_days must be a retention value CloudWatch Logs accepts, for example 7, 14, 30 or 90."
  }
}

variable "log_kms_key_arn" {
  description = "KMS key that encrypts the flow log group. CloudWatch Logs must be allowed to use it."
  type        = string
}
