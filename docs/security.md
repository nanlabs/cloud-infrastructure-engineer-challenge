# Security

## Controls in place

| Area | Control |
|---|---|
| Network | Lambda and RDS in private subnets; the database tier has no route to the internet; RDS is `publicly_accessible = false`. |
| Network | Security groups reference each other: the DB accepts `5432` only from the Lambda SG; the Lambda has no inbound rules. |
| Network | Default security group stripped of all rules; public subnets do not auto-assign public IPs. |
| Network | VPC Flow Logs (all traffic) to CloudWatch, written by an IAM role with confused-deputy protection. |
| Identity | Lambda role: AWS managed `AWSLambdaVPCAccessExecutionRole` + `secretsmanager:GetSecretValue` on a single secret ARN. |
| Identity | API Gateway may invoke the function only from this API and the `GET /info` route (`source_arn`). |
| Secrets | DB password generated, stored and rotated by RDS in Secrets Manager; never in code, variables or Terraform state. |
| Encryption | RDS storage encrypted (KMS); TLS enforced server-side (`rds.force_ssl = 1`) and verified client-side against the RDS CA bundle. |
| Encryption | HTTPS end to end: CloudFront redirects HTTP to HTTPS and uses TLS 1.2 to the origin. |
| Edge | AWS Shield Standard (CloudFront), managed security headers (HSTS, nosniff, frame options), API throttling. |
| Information disclosure | Error responses only include the exception type; stack traces go to the logs only. |
| Supply chain | GitHub Actions pinned to commit SHAs, read-only workflow token, Dependabot; provider lock file committed. |
| Shift-left | pre-commit + CI: secret detection, `tflint` (AWS ruleset), blocking Trivy scan, `ruff` with bandit rules. |

## Accepted risks (Trivy findings)

The CI gate blocks on HIGH/CRITICAL findings. These are accepted on purpose and annotated inline with `#trivy:ignore`:

| ID | Severity | Resource | Why it is accepted |
|---|---|---|---|
| AWS-0104 | CRITICAL | Lambda SG egress `443` to `0.0.0.0/0` | Required to reach Secrets Manager (a public AWS endpoint) through the NAT Gateway, which is the architecture the challenge asks for. A Secrets Manager VPC interface endpoint would let us restrict it to the VPC CIDR (~US$15/month for 2 AZs). |
| AWS-0011 | HIGH | CloudFront without WAF | WAF costs ~US$5/month + rules; mitigated by API Gateway throttling and Shield Standard. First item to add for production. |
| AWS-0095 | HIGH | SNS alarm topic unencrypted | CloudWatch cannot publish to topics encrypted with the AWS managed `aws/sns` key, and alarm payloads are not sensitive. A customer managed KMS key would fix it. |
| AWS-0010 | MEDIUM | CloudFront access logs | Every request that reaches the origin is already in the API Gateway access logs. |

Lower-severity findings, not blocking, left as improvements:

| ID | Severity | Note |
|---|---|---|
| AWS-0177 | MEDIUM | RDS deletion protection is a variable (`db_deletion_protection`), `false` so the challenge environment can be destroyed. Set to `true` in production. |
| AWS-0176 | MEDIUM | IAM database authentication: see ADR-005. |
| AWS-0017 | LOW | Log groups use CloudWatch's default encryption, not a customer managed KMS key. |
| AWS-0066 | LOW | X-Ray tracing not enabled on the Lambda. |
| AWS-0133 | LOW | RDS Performance Insights not enabled. |

## Not in scope / production next steps

Security items only; the full prioritized list is in the [README](../README.md#suggested-next-steps).

- **Authentication:** `GET /info` is public by design for the challenge. In production, add a JWT/IAM authorizer on the HTTP API and WAF on CloudFront, and only accept traffic that comes through CloudFront (secret origin header or a custom domain).
- **Least-privilege database user:** create a read-only role through a migration and point the Lambda at its secret instead of the master user.
- **Custom domain** with an ACM certificate to enforce a modern TLS policy (`TLSv1.2_2021`) at the edge.
