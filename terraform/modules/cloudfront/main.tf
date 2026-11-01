# /info reports live status, so responses must never be cached at the edge
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# API Gateway routes on its own Host header: forward everything except Host
data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

# HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, X-XSS-Protection
data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

locals {
  origin_id = "api-gateway"
}

# Accepted risks (documented in docs/security.md):
# - WAF (AVD-AWS-0011): cost not justified for this scope; API Gateway throttling + Shield Standard apply.
# - Access logging (AVD-AWS-0010): every request reaching the origin is already in the API Gateway access logs.
#trivy:ignore:AVD-AWS-0010
#trivy:ignore:AVD-AWS-0011
resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  comment         = var.comment
  price_class     = var.price_class
  http_version    = "http2and3"
  is_ipv6_enabled = true

  origin {
    origin_id   = local.origin_id
    domain_name = var.origin_domain_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id           = local.origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
