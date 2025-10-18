variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
  default     = []
}

variable "azs_count" {
  description = "Number of AZs to be created"
  type        = number
  default     = 2
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnets CIDR"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnets CIDR"
  type        = list(string)
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
