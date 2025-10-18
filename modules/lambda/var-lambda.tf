variable "subnet_ids" {
  type    = list(any)
  default = []
}

variable "db_endpoint" {
  description = "The endpoint address of the database"
  type        = string
}

variable "db_name" {
  description = "The name of the database"
  type        = string
}

variable "db_port" {
  description = "The port number the database is listening on"
  type        = number
}

variable "db_instance_master_user_secret_arn" {
  description = "The ARN of the RDS master secret (from AWS Secrets Manager)"
  type        = string
}

variable "security_group_id" {
  description = "The security group ID to associate with the RDS instance"
  type        = string
  default     = ""
}

variable "project" {
  type = string
}

variable "tags" {
  type        = map(string)
  description = "Tags default"
  default = {
  }
}
