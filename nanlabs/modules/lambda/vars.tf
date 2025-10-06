variable "name" {
  type = string
}
variable "memory_mb" {
  type = number
}
variable "timeout_sec" {
  type = number
}
variable "log_group_name" {
  type = string
}
variable "environment" {
  type = map(string)
}
variable "use_localstack" {
  type = bool
}
variable "subnet_ids" {
  type = list(string)
}
variable "security_group_ids" {
  type = list(string)
}