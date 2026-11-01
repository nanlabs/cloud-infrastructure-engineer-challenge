variable "name" {
  description = "Name prefix for all network resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC. Must be /16 to /20 so it can be split into /24-ish subnets."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "vpc_cidr must be a valid IPv4 CIDR between /16 and /20."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to spread the subnets across (RDS needs at least 2)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "true: one shared NAT Gateway (cheaper). false: one NAT Gateway per AZ (no cross-AZ single point of failure)."
  type        = bool
  default     = true
}

variable "database_port" {
  description = "Port the database listens on; used by the Lambda <-> database security group rules."
  type        = number
  default     = 5432
}

variable "enable_flow_logs" {
  description = "Send VPC Flow Logs (all traffic) to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention in days for the VPC Flow Logs log group."
  type        = number
  default     = 14
}
