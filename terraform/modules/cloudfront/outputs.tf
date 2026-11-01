output "distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.id
}

output "domain_name" {
  description = "CloudFront domain name, e.g. d111111abcdef8.cloudfront.net"
  value       = aws_cloudfront_distribution.this.domain_name
}
