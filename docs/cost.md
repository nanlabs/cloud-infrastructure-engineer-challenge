# Cost

What a deployment costs while it runs, so nobody is surprised. Region
us-east-1, on-demand, 730 hours a month.

The rates are marked by how far they were checked. **Confirmed** rates were read
from AWS's published pricing. **Unverified** rates are from memory and must be
checked in the [AWS Pricing Calculator](https://calculator.aws/) before relying
on them.

| Item | Rate | Status | dev per month | prod per month |
| ---- | ---- | ------ | ------------- | -------------- |
| NAT gateway, hours | $0.045 per hour each | confirmed (pricing page) | $32.85 (1) | $65.70 (2) |
| Public IPv4 address of each NAT gateway | $0.005 per hour each | confirmed (price list) | $3.65 (1) | $7.30 (2) |
| RDS db.t4g.micro PostgreSQL | $0.016 per hour, doubled for Multi-AZ | unverified | $11.68 | $23.36 |
| Database storage, 20 GiB gp3 | $0.115 per GiB-month, doubled for Multi-AZ | unverified | $2.30 | $4.60 |
| KMS keys, 2 (application stack) | $1 per key-month | unverified | $2.00 | $2.00 |
| Secrets Manager, 1 secret | $0.40 per month | unverified | $0.40 | $0.40 |
| CloudWatch alarms | $0.10 per alarm-month | unverified | $0.90 (9) | $1.00 (10) |
| **Application stack fixed total** | | | **about $54** | **about $104** |

If you also create the shared remote-state bucket with `terraform/bootstrap`, its
customer-managed KMS key adds **$1.00 per month** (unverified) plus a few cents of
S3 storage across the account; both survive `make destroy` until the bootstrap
bucket is removed.

That is roughly $0.07 an hour for dev and $0.14 an hour for prod. On top of it,
Lambda, API Gateway, log ingestion and NAT data transfer cost a few dollars at
most at demonstration traffic (unverified); they scale with requests.

A short evaluation deployment of the dev profile, a couple of hours, therefore
costs well under a dollar. Forgetting it for a month costs about $54.

## What dominates

The NAT gateway is the largest line, more than the database. It is also what the
challenge asks for, so it stays; the other lines are small.

## Levers

- **Tear it down** when done: `make destroy ENV=dev CONFIRM=dev`.
- **`nat_gateway_mode = "single"`** halves the NAT cost, at the price of one zone
  being a single point of failure for outbound access. Dev already uses it.
- **Shorter log and backup retention** lowers storage; both are variables.
- **Delete leftover snapshots.** A final snapshot outlives the instance and keeps
  billing.
- **VPC endpoints** for Secrets Manager and the RDS API would remove the need for
  the NAT gateway's outbound path, but they are billed per endpoint and zone, so
  they are not automatically cheaper. Compare before switching.
