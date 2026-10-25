# First deployment: dev in us-east-1

Recorded on 2026-10-24 (UTC), in a personal AWS account (ID and API host redacted below).
The stack was applied with `make`, verified on a cold start and a warm call, checked in
CloudWatch Logs and Logs Insights, planned again from the GitHub workflow, and destroyed
from the GitHub workflow.

## What was run

| Step | How | Result |
| ---- | --- | ------ |
| Plan | `make plan ENV=dev REGION=us-east-1` | 68 to add, 0 to change, 0 to destroy |
| Apply | `make apply ENV=dev REGION=us-east-1` | 68 added |
| Verify (cold + warm) | `make verify`, then `curl` | HTTP 200 on both calls (`latency_ms` 52.4 ms cold, 1.6 ms warm), shown below |
| Second plan | `terraform plan -detailed-exitcode` | exit 0 (`No changes`), confirming `rds.force_ssl` (`pending-reboot`), `log_min_duration_statement` (`immediate`) and `log_statement` (`immediate`) all settle |
| Saved Logs Insights queries | `aws logs start-query` for all three definitions | caught a bug in `api-latency-percentiles` (fixed in [#11](https://github.com/supermavster/cloud-infrastructure-engineer-challenge/pull/11) and applied in-place) |
| Plan from the workflow | workflow `deploy`, action `plan`, from `main` ([run](https://github.com/supermavster/cloud-infrastructure-engineer-challenge/actions/runs/40054251665)) | **No changes**, so `make` and the workflow share one state; 0 unmasked account ID or bucket occurrences |
| Destroy from the workflow | workflow `deploy`, action `destroy`, `confirm=dev` ([run](https://github.com/supermavster/cloud-infrastructure-engineer-challenge/actions/runs/40054606182)) | 68 destroyed in 22 minutes (waiting on Lambda VPC ENI release); 0 unmasked occurrences |

The local `make` commands used an SSO administrator profile and an existing S3 state
bucket (`STATE_BUCKET`). The workflow used an IAM role assumed through GitHub's OIDC
provider.

## The endpoint

`GET /info` answered `200` on the first call after the apply (a cold start, including the
Secrets Manager read decrypted via the `data` KMS key, the `rds:DescribeDBInstances` call,
and the verified TLS handshake):

```json
{
  "status": "ok",
  "timestamp": "2026-10-24T02:17:24Z",
  "request_id": "ffe64e5d-40ae-48d9-9358-996be27d4eee",
  "database": {
    "connected": true,
    "engine": "postgres",
    "version": "17.9",
    "database": "appdb",
    "in_recovery": false,
    "uptime_seconds": 630,
    "tls": true,
    "latency_ms": 52.4
  },
  "instance": {
    "class": "db.t4g.micro",
    "status": "available",
    "multi_az": false,
    "availability_zone": "us-east-1b",
    "storage_type": "gp3",
    "allocated_storage_gb": 20,
    "backup_retention_days": 7
  },
  "runtime": {
    "region": "us-east-1",
    "cold_start": true
  }
}
```

A second call one second later reused the warm execution environment, the cached secret
and metadata, and the open TLS connection (`latency_ms` dropped from `52.4` to `1.6`):

```json
{
  "status": "ok",
  "timestamp": "2026-10-24T02:17:25Z",
  "request_id": "db9543a1-64c0-4fb1-9996-17c18f8f88a8",
  "database": {
    "connected": true,
    "engine": "postgres",
    "version": "17.9",
    "database": "appdb",
    "in_recovery": false,
    "uptime_seconds": 631,
    "tls": true,
    "latency_ms": 1.6
  },
  "instance": {
    "class": "db.t4g.micro",
    "status": "available",
    "multi_az": false,
    "availability_zone": "us-east-1b",
    "storage_type": "gp3",
    "allocated_storage_gb": 20,
    "backup_retention_days": 7
  },
  "runtime": {
    "region": "us-east-1",
    "cold_start": false
  }
}
```

Only `GET /info` exists. Every other path and method answered `404`:

| Request | Status |
| ------- | ------ |
| `GET /info` | 200 |
| `GET /` | 404 |
| `GET /other` | 404 |
| `POST /info` | 404 |
| `DELETE /info` | 404 |

## CloudWatch logs and saved queries

All five stack log groups were encrypted with the `observability` customer-managed KMS
key:

- **Lambda (`/aws/lambda/info-api-dev-info`):** structured JSON records with `request_id`
  matching the HTTP response and `latency_ms`:

  ```json
  {"timestamp": "2026-10-24T02:17:24Z", "level": "INFO", "message": "database ok", "logger": "root", "requestId": "ffe64e5d-40ae-48d9-9358-996be27d4eee", "request_id": "ffe64e5d-40ae-48d9-9358-996be27d4eee", "latency_ms": 52.4}
  {"timestamp": "2026-10-24T02:17:25Z", "level": "INFO", "message": "database ok", "logger": "root", "requestId": "db9543a1-64c0-4fb1-9996-17c18f8f88a8", "request_id": "db9543a1-64c0-4fb1-9996-17c18f8f88a8", "latency_ms": 1.6}
  ```

- **API Gateway access logs (`/aws/apigateway/info-api-dev-info/access`):**

  ```json
  {"integrationErrorMessage":"-","integrationLatency":"2239","integrationStatus":"200","requestId":"FuhAAgktIAMEa4A=","requestTime":"24/Oct/2026:02:17:22 +0000","responseLatency":"2244","responseLength":"531","routeKey":"GET /info","sourceIp":"<REDACTED>","status":"200"}
  {"integrationErrorMessage":"-","integrationLatency":"40","integrationStatus":"200","requestId":"FuhAZhEVoAMEblQ=","requestTime":"24/Oct/2026:02:17:25 +0000","responseLatency":"44","responseLength":"531","routeKey":"GET /info","sourceIp":"<REDACTED>","status":"200"}
  ```

- **RDS PostgreSQL logs (`/aws/rds/instance/info-api-dev-db/postgresql`)** and **VPC Flow
  Logs (`/aws/vpc/info-api-dev/flow-logs`)** both received live records.
- **Saved Logs Insights queries:** after [#11](https://github.com/supermavster/cloud-infrastructure-engineer-challenge/pull/11),
  `info-api-dev/api-latency-percentiles` returned `requests = 2`, `avg_ms = 1144`,
  `p99_ms = 2244` on the two requests above, and the two error queries completed with
  0 matching records on the healthy run.

## What was checked in the account

| Check | Observed |
| ----- | -------- |
| RDS instance | `available`, PostgreSQL `17.9`, `PubliclyAccessible` false, storage encrypted with `alias/info-api-dev-data`, Enhanced Monitoring interval `60`, exporting `postgresql` and `upgrade` logs |
| Master password secret | managed by RDS in Secrets Manager, status `active`, encrypted with `alias/info-api-dev-data` |
| Parameter group | `in-sync`; `rds.force_ssl = 1` (`pending-reboot`), `log_min_duration_statement = 500` (`immediate`), `log_statement = ddl` (`immediate`) |
| KMS keys | `alias/info-api-dev-data` and `alias/info-api-dev-observability`, both with automatic rotation enabled |
| Data subnets' route table | one route, `10.20.0.0/16 -> local`: no route out |
| Alarms | all 9 alarms (`api-5xx`, `lambda-duration-p99`, `lambda-errors`, `lambda-throttles`, `nat-port-allocation-1`, `rds-connections-high`, `rds-cpu-high`, `rds-memory-low`, `rds-storage-low`) in state `OK` (`treat_missing_data = "notBreaching"`) |

After the workflow destroy completed, the account had no RDS instance or snapshot, no NAT
gateway or Elastic IP, no VPC, Lambda, HTTP API, log group, alarm, saved query or SNS
topic from this stack, and both KMS keys were in `PendingDeletion`.

## What the deployments found

Three problems were caught earlier on the sibling lean stack and ported here in
[#9](https://github.com/supermavster/cloud-infrastructure-engineer-challenge/pull/9)
(`rds.force_ssl` apply method, masking `STATE_BUCKET` and `AWS_ROLE_ARN` as secrets, and
GitHub's immutable OIDC subject prefix). Deploying this extended stack caught a fourth:

- **`info-api-dev/api-latency-percentiles` returned `p99_ms = 0` and omitted `avg_ms`.**
  `aws_apigatewayv2_stage` builds the access log format with `jsonencode`, which quotes
  `$context.responseLatency` as a JSON string (`"2244"`). Keeping the quotes is required
  so `-` values do not produce invalid JSON, but CloudWatch Logs Insights treats an
  auto-discovered string field as non-numeric in `avg()` and `pct()`. Fixed in
  [#11](https://github.com/supermavster/cloud-infrastructure-engineer-challenge/pull/11)
  by parsing `responseLatency` into a numeric field first, with a mutation-checked test.

## What was not tested

- `terraform/bootstrap` (the run reused an existing S3 state bucket via `STATE_BUCKET`).
- The workflow's `apply` and `unlock` actions, and its access-key authentication path.
- `prod` (Multi-AZ RDS, one NAT gateway per zone, concurrency cap, required reviewer).
- Regions other than `us-east-1`.
- A failing database (`503` categories are covered by unit and integration tests) and an
  alarm firing to the encrypted SNS topic.
