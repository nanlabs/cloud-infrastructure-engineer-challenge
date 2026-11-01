# Architecture Decision Records

Short ADRs for the decisions that shape the solution. Status of all of them: **Accepted**.

## ADR-001: Terraform as the IaC tool

- **Context:** the challenge prefers Terraform; reviewers need to read and run the code easily.
- **Decision:** Terraform (>= 1.10) with the official AWS provider (~> 6.0), structured as a root module plus small, single-purpose local modules.
- **Alternatives:** AWS CDK / Pulumi (real programming languages, but an extra runtime and abstraction layer to review); CloudFormation (AWS-only, more verbose). `terraform-aws-modules` community modules are the usual production choice, but they hide most of the resources behind many inputs; for a reviewable challenge, explicit modules make every networking and security decision visible.
- **Consequences:** the whole stack is readable in a few hundred lines; `terraform plan` gives a reviewable diff.

## ADR-002: RDS PostgreSQL as the backend

- **Context:** the backend can be RDS, a self-hosted database on EC2, or an application on EC2.
- **Decision:** Amazon RDS for PostgreSQL 17 on `db.t4g.micro` (Graviton).
- **Alternatives:** PostgreSQL on EC2 means owning OS patching, backups, failover and monitoring; WordPress on EC2 adds an application tier that does not serve the goal.
- **Consequences:** Multi-AZ, automated backups with PITR, storage autoscaling, encryption and Secrets Manager integration are configuration flags, not code.

## ADR-003: API Gateway HTTP API instead of REST API

- **Context:** one route (`GET /info`) proxied to a Lambda.
- **Decision:** HTTP API (API Gateway v2) with a Lambda proxy integration.
- **Alternatives:** REST API adds usage plans, API keys, request validation and native WAF, none of which are needed for this scope, and costs ~3.5x more per request.
- **Consequences:** simpler configuration (auto-deployed `$default` stage), lower latency and cost. If WAF is needed it is attached at CloudFront (ADR-004).

## ADR-004: CloudFront (not an ALB) for the traffic distribution bonus

- **Context:** the bonus asks for an Application Load Balancer or CloudFront.
- **Decision:** CloudFront in front of API Gateway.
- **Alternatives:** an ALB cannot front an API Gateway; it would replace it (ALB -> Lambda target), which contradicts the API Gateway requirement. It also costs a fixed ~US$16+/month.
- **Consequences:** TLS at the edge, HTTP/3, AWS Shield Standard, security headers and one place to add WAF or a custom domain later. Caching is disabled because `/info` is live status. API Gateway stays reachable directly (see [security.md](security.md)).

## ADR-005: Database credentials managed by RDS in Secrets Manager

- **Context:** the Lambda needs database credentials; they must never be in code, variables or Terraform state.
- **Decision:** `manage_master_user_password = true`: RDS generates the password, stores it in Secrets Manager and rotates it. The Lambda gets `GetSecretValue` on that one secret, caches it per container and refreshes it if authentication fails after a rotation.
- **Alternatives:** `random_password` in Terraform (the secret ends up in the state); IAM database authentication (requires creating a database role with SQL inside the private network, so Terraform alone cannot bootstrap it); RDS Proxy (better connection pooling, extra cost that is not needed at this scale).
- **Consequences:** zero secrets in the repo and state. Trade-off: the Lambda uses the master user (see Assumptions in the README).

## ADR-006: Python 3.13 + pg8000 on arm64

- **Context:** the Lambda needs a PostgreSQL driver and must be buildable from any developer OS (the author works on Windows).
- **Decision:** Python 3.13 with `pg8000`, a pure-Python driver; arm64 (Graviton) architecture.
- **Alternatives:** `psycopg2` / `psycopg` need native wheels that must match the Lambda platform (Docker or a Lambda layer to build); Node.js would work equally well.
- **Consequences:** `scripts/build_lambda.py` produces an identical package on Windows, macOS, Linux or CI; arm64 is ~20% cheaper than x86_64.

## ADR-007: Availability vs cost defaults

- **Decision:** RDS **Multi-AZ on** by default; **one shared NAT Gateway** by default (`single_nat_gateway = false` gives one per AZ).
- **Rationale:** the database is the stateful component, so losing its AZ means downtime and possibly data loss; Multi-AZ on `db.t4g.micro` costs ~US$14/month extra (standby instance and storage). A second NAT Gateway costs ~US$36/month with its Elastic IP and, for an AZ outage, only affects the Lambda's access to Secrets Manager from that AZ, and only on cold starts. Route tables are already per AZ, so changing it is one variable.

## ADR-008: Local Terraform state by default

- **Decision:** local state, with the S3 backend (native S3 locking, `use_lockfile`) documented in the README.
- **Rationale:** reviewers deploy into their own accounts; requiring a pre-existing bucket would add a bootstrap step. In a team setting the S3 backend is mandatory.
