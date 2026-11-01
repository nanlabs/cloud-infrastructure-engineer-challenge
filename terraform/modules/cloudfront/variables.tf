variable "origin_domain_name" {
  description = "Domain name of the API Gateway endpoint (without scheme), e.g. abc123.execute-api.us-east-1.amazonaws.com"
  type        = string

  validation {
    condition     = !startswith(var.origin_domain_name, "https://")
    error_message = "origin_domain_name must not include the scheme."
  }
}

variable "comment" {
  description = "Comment shown in the CloudFront console."
  type        = string
  default     = ""
}

variable "price_class" {
  description = "Edge locations to use. PriceClass_100 = North America + Europe (cheapest)."
  type        = string
  default     = "PriceClass_100"
}
