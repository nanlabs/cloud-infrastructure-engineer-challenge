variable "project_name" {
  type    = string
  default = "ls-api"
}

variable "lambda_memory_mb" {
  type    = number
  default = 256
}
variable "lambda_timeout_sec" {
  type    = number
  default = 10
}
variable "env" {
  type    = string
  default = "dev"
}

variable "db_host" {
  type    = string
  default = "pg-local"
} # o "host.docker.internal"
variable "db_port" {
  type    = number
  default = 5432
}
variable "db_name" {
  type    = string
  default = "appdb"
}
variable "db_user" {
  type    = string
  default = "appuser"
}
variable "db_password" {
  type    = string
  default = "apppass"
} # en local, simple
