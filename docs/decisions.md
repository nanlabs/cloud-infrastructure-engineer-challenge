# Decisions

The choices that shaped this repository, what was rejected, and what each one
costs. Each is a trade-off, so each says when to revisit it.

## 1. Terraform

**Chosen.** Terraform, with the AWS provider pinned to 6.x and Terraform itself to
1.11 or newer (below 2.0).

**Rejected.** AWS CDK, CloudFormation and SAM tie the work to AWS and make the
change set harder to review than a plan. Pulumi has a smaller ecosystem of
checks. OpenTofu would probably work unchanged but was not tested.

**Why.** The challenge prefers Terraform. The plan is a reviewable diff, the AWS
provider is mature, `terraform test` can mock AWS so the configuration is tested
without an account, and tflint, checkov and terraform-docs are built around it.

**Costs.** State has to be managed (see 9), and the 1.11 minimum excludes older
installations.

## 2. One root module, settings outside the code

**Chosen.** `terraform/` is a thin root that wires modules together.
Per-environment values live in `environments/<env>/terraform.tfvars`, and the
state location is passed at `init` (the bucket, and a key per environment and
region). Variables that differ per environment have no default.

**Rejected.** Terragrunt, and separate stacks that read each other's state. Both
add ordering and coupling that a single environment does not need, and a reviewer
would have to run several applies.

**Why.** One `init` and one `apply`, and the same code deploys to any account.

**Revisit** when there are several teams or accounts and a stack's blast radius
needs to be smaller.

## 3. Own modules from plain resources

**Chosen.** Seven small modules written against the AWS provider directly.

**Rejected.** The community `terraform-aws-modules`. They are well maintained,
but networking and IAM are what this challenge evaluates, so they should be
visible in the code, and there is no third-party code to review or pin.

**Costs.** More code to maintain. Switching later is a contained change, because
each module has a narrow interface.

## 4. RDS PostgreSQL

**Chosen.** RDS PostgreSQL 17.

**Rejected.** A database or application on EC2.

**Why.** AWS handles backups, point-in-time restore, Multi-AZ failover, patching
and storage encryption. EC2 would mean owning all of that, plus SSH access and
operating-system patching, for no benefit here. It also covers two of the
optional items (high availability and backups).

## 5. HTTP API, not REST API

**Chosen.** API Gateway HTTP API.

**Rejected.** REST API.

**Why.** It is cheaper and simpler, and the REST-only features (AWS WAF, API
keys, usage plans, X-Ray) are not needed for one public route.

**Costs.** No WAF without CloudFront in front. Revisit if the endpoint needs
per-client limits or WAF.

## 6. Database password managed by RDS

**Chosen.** `manage_master_user_password`: RDS creates the password, stores it in
Secrets Manager under the data key, and rotates it every seven days. The Lambda
reads it at run time and re-reads it after an authentication failure.

**Rejected.** A `random_password` resource, whose value ends up in Terraform
state. A write-only password argument keeps it out of state but leaves rotation
to us. IAM database authentication for the master user would need a database
user created first.

**Why.** No password in code, variables or state, and rotation is automatic.

**Revisit** to give the function its own read-only database user with IAM
authentication, which would narrow what a stolen credential can do.

## 7. Verified TLS

**Chosen.** `rds.force_ssl = 1` on the server, and the Lambda verifies the
certificate chain and hostname against the bundled RDS certificate authority
bundle.

**Rejected.** Encrypting without checking the certificate, which stops
eavesdropping but not impersonation.

**Costs.** The bundle is a 170 KB file in the repository; the README next to it
says where it came from and how to refresh it. The behaviour against a real RDS
certificate is only provable once deployed.

## 8. NAT layout is a setting

**Chosen.** `nat_gateway_mode`: `single` (one shared gateway, dev) or `per_az`
(one per zone, prod).

**Rejected.** Always one per zone: it doubles the largest fixed cost of the dev
profile for availability nobody needs there.

**Costs.** In `single` mode the zone holding the gateway is a single point of
failure for outbound access.

## 9. Deletion protection, not `prevent_destroy`

**Chosen.** The database uses `deletion_protection`, a final snapshot with a
unique name, and both are settings.

**Rejected.** `prevent_destroy`, because a lifecycle argument cannot be set from
a variable, so nobody could tear down a throwaway environment.

**Exception.** The state bucket uses `prevent_destroy`: losing it orphans every
environment, and it is not meant to be destroyed with them.

## 10. S3 native state locking

**Chosen.** The S3 backend with `use_lockfile`, available from Terraform 1.11.

**Rejected.** A DynamoDB lock table, whose arguments are deprecated in favour of
this. One fewer resource to create and pay for.

## 11. Cap the connections instead of adding RDS Proxy

**Chosen.** An API throttle and a Lambda concurrency cap bound the database
connections. The arithmetic is in [architecture.md](architecture.md#capacity-and-timeouts).

**Rejected.** RDS Proxy. It is the right answer at higher scale, but it adds a
resource that bills by the hour and one more thing to secure, and the cap already
keeps connections well under the limit here.

**Revisit** when the request rate, or the number of functions sharing the
database, grows.

## 12. Checks run through pinned tools

**Chosen.** checkov and actionlint run through `uvx` at exact versions, and CI
calls the same Makefile targets a developer does.

**Why.** The checkov package installed on the author's workstation had a broken
wrapper, and a bare command would also have made results depend on whatever was
installed. Pinning removes both problems and keeps local and CI results the same.

## 13. Two ways to deploy, one set of commands

**Chosen.** `make` for people who have the tools, and a `workflow_dispatch`
workflow for people who would rather click. The workflow only calls the make
targets, so there is one implementation to review and both paths act on the same
state. It uses OIDC when a role is configured and access keys otherwise, and prod
waits for a reviewer.

**Costs.** `apply` plans and applies in the same run instead of passing a saved
plan between jobs, which would need the plan and the packaged function to travel
together. Run `plan` first to read it before applying.
