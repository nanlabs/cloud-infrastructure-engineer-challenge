variable "name" {
  description = "Function name; also used for the IAM role and log group."
  type        = string
}

variable "description" {
  description = "Function description."
  type        = string
  default     = ""
}

variable "source_dir" {
  description = "Directory with the built package (output of scripts/build_lambda.py)."
  type        = string
}

variable "handler" {
  description = "Function entrypoint."
  type        = string
  default     = "handler.lambda_handler"
}

variable "runtime" {
  description = "Lambda runtime. Keep in sync with PYTHON_VERSION in scripts/build_lambda.py."
  type        = string
  default     = "python3.13"
}

variable "architecture" {
  description = "Instruction set. arm64 (Graviton) is ~20% cheaper than x86_64."
  type        = string
  default     = "arm64"
}

variable "memory_size" {
  description = "Memory in MB (CPU scales with it)."
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Timeout in seconds. Must stay below the API Gateway integration timeout (30s)."
  type        = number
  default     = 15
}

variable "subnet_ids" {
  description = "Private subnets where the function ENIs are placed."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to the function ENIs."
  type        = list(string)
}

variable "secret_arn" {
  description = "ARN of the Secrets Manager secret with the database credentials (read-only access is granted)."
  type        = string
}

variable "environment_variables" {
  description = "Extra environment variables (no secrets: they are visible in the console)."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "Retention in days for the function log group."
  type        = number
  default     = 14
}
