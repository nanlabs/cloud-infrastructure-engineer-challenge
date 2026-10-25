variable "region" {
  description = "AWS region for the state bucket, for example us-east-1."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "region must look like us-east-1."
  }
}

variable "bucket_name" {
  description = "Globally unique name of the Terraform state bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters: lowercase letters, digits and hyphens, not starting or ending with a hyphen."
  }
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep superseded state versions before they are deleted."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_retention_days >= 1
    error_message = "noncurrent_version_retention_days must be at least 1."
  }
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    Project   = "info-api-extended"
    ManagedBy = "terraform"
  }
}
