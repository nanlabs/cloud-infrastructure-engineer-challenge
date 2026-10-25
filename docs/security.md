# Security

What could go wrong, what is in place against it, and what is accepted. For the
access rules and permissions themselves see [architecture.md](architecture.md).

## Threats

A STRIDE pass over the request path.

| Threat | Control | Gap |
| ------ | ------- | --- |
| **Spoofing** a caller | None, by design: the challenge asks for a working public endpoint and the response is not sensitive. Throttled at the gateway | Anyone can call it. A JWT authorizer is the next step if that changes |
| **Spoofing** the database | The Lambda verifies the server certificate chain and hostname against the RDS bundle | Proven only against a real RDS certificate once deployed |
| **Tampering** in transit | TLS at API Gateway; TLS required and verified to the database | |
| **Tampering** with the infrastructure | Changes only through reviewed Terraform and CI; signed commits; the apply step uses a saved plan | Anyone with AWS console access can still change resources by hand |
| **Repudiation** | API access logs (request id, source IP, route, status), JSON function logs with the same request id, VPC flow logs, database logs | CloudTrail is assumed to be enabled at account level and is not managed here |
| **Information disclosure** from responses | Failures return a category only; no host, user, secret or stack trace leaves the function | |
| **Information disclosure** at rest | Database, backups, secret, logs and alert topic encrypted with customer-managed rotating keys; the state bucket is encrypted and blocks public access | RDS enhanced monitoring writes to a log group RDS creates, with default encryption |
| **Information disclosure** of the password | Generated and rotated by RDS; never in code, variables or Terraform state; excluded from `repr` and logs | The function uses the master user, so a stolen credential is powerful (see below) |
| **Denial of service** | Stage throttle, Lambda concurrency cap (prod), short timeouts, connection arithmetic in [architecture.md](architecture.md#capacity-and-timeouts), alarms on throttles, 5xx and connections | No WAF; a large flood still bills Lambda and NAT traffic |
| **Elevation of privilege** | Role limited to one secret, one key (only via Secrets Manager), one database and its own log group; the database accepts one security group on one port; no IAM users or static keys in the deployed application stack | The network interface actions need `*` because AWS offers no narrower scope |

## Accepted risks

Each of these is deliberate, with the way out:

1. **The master database user is used by the function.** It is the only user
   RDS creates. A dedicated read-only user with IAM authentication would shrink
   what a leaked credential can do. Not done because creating a database user
   needs a one-off bootstrap step that does not fit a single `apply`.
2. **Lambda egress on 443 goes to anywhere.** AWS publishes no prefix list for
   Secrets Manager or the RDS API. Interface VPC endpoints would let the rule
   target only the VPC and would remove the dependency on the NAT gateway. The
   challenge asks for a NAT gateway, so this stays a documented improvement.
3. **No authorizer or WAF on the endpoint.** See the table above. An HTTP API
   cannot use WAF; CloudFront in front could, but the direct API address would
   still need closing.
4. **Key policies delegate to the account.** Each key policy lets the account's IAM
   policies decide, which is the AWS default, so any principal with `kms:*` in IAM
   can use them.
5. **Dev has no deletion protection and skips the final snapshot.** So it can be
   torn down. Prod keeps both.

## Secrets and CI

- No secret is committed. gitleaks runs on every commit and scans the whole git
  history in CI.
- `.tfvars` files hold only non-sensitive settings. State, plans and `.env`
  files are gitignored.
- The CI workflow uses a read-only token, no AWS credentials, checkout without
  persisted credentials, and actions pinned to commit SHAs. It runs on
  `pull_request`, so code from a fork never gets secrets.
- Provider and Python dependencies are locked with hashes, the PostgreSQL image is
  pinned by digest, and Dependabot proposes updates.

## Scanner exceptions

checkov passes with these skips. Every skip sits next to the code it applies to,
with its reason, and this table is that list.

| Check | Where | Why |
| ----- | ----- | --- |
| CKV_AWS_109, 111, 356 | key policies (bootstrap, kms) | In a key policy `Resource: "*"` means this key only |
| CKV_AWS_111, 356 | Lambda role | Network interface actions cannot be limited to a resource |
| CKV_AWS_18 | state bucket | Access logging needs a second bucket; CloudTrail covers auditing |
| CKV_AWS_144 | state bucket | Cross-region replication is out of scope |
| CKV2_AWS_62 | state bucket | No consumers of state object events |
| CKV_AWS_338 | every log group | Retention is a variable; a year of logs is not worth the cost here |
| CKV_AWS_50 | Lambda | X-Ray tracing is not enabled |
| CKV_AWS_115 | Lambda | Reserved concurrency is per environment; small accounts cannot reserve any |
| CKV_AWS_116 | Lambda | Invoked synchronously, so a dead letter queue would never receive anything |
| CKV_AWS_173 | Lambda | The environment holds the secret's ARN, not a secret |
| CKV_AWS_272 | Lambda | Code signing is out of scope |
| CKV_AWS_309 | API route | Public by design; the response is not sensitive |
| CKV_AWS_157 | database | Multi-AZ is per environment, on in prod |
| CKV_AWS_353, 354 | database | Performance Insights is not enabled |
| CKV_AWS_394 | zone lookup | Only the first zones by name are used and new zones sort last |
| CKV2_AWS_5 | security groups | Attached in other modules; checkov cannot follow module outputs (confirmed by removing the skip) |
