# NETWORK

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

# API

variable "aws_region" {
  description = "The AWS region to create things in."
  type        = string
  default     = "us-east-1"
}

variable "stage_name" {
  type    = string
  default = "dev"
}

# RDS

variable "instance_class" {
  type    = string
  default = "db.m5.large"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  type    = number
  default = 100
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "dbname" {
  type    = string
  default = "postgres"
}

variable "engine" {
  type    = string
  default = "postgres"
}

variable "engine_version" {
  type    = string
  default = "17.2"
}

variable "username" {
  type    = string
  default = "postgres"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project" {
  type    = string
  default = "cloud-infra-challenge"
}

variable "owner" {
  type    = string
  default = ""
}
