variable "stage_name" {
  type    = string
  default = "dev"
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

variable "lambda_invoke_arn" {
  description = "The ARN used to invoke the Lambda function"
  type        = string
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
}
