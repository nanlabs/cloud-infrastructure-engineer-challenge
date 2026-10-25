# Operations

Day-to-day use. The first deployment is in the [README](../README.md#deploy).
Commands that call AWS use the CLI flags listed by `aws <command> help`; none of
them has been run against a real account here.

## Reading a response

`200` means the database answered. `503` means it did not, and `database.error`
says why. Nothing else is in the body on purpose; the details are in the log,
under the same `request_id`.

| `database.error` | Meaning | Look at first |
| ---------------- | ------- | ------------- |
| `timeout` | Connect or statement limit reached | `rds-cpu-high` and `rds-connections-high`; the database may be overloaded |
| `unavailable` | Refused, unreachable, or too many connections | Is the instance `available`? Is the security group rule intact? Connection count |
| `authentication` | Rejected even after a fresh secret was read | Was the secret edited by hand? Does the role still have `kms:Decrypt` through Secrets Manager? |
| `credentials` | The secret could not be read | NAT gateway health; the role's `secretsmanager:GetSecretValue`; the secret's state |
| `tls` | Certificate or TLS negotiation failed | Was the instance's certificate authority changed from `rds-ca-rsa2048-g1`? Is the bundled CA file current? |

`500` means the function is misconfigured (`configuration`: check the environment
variables) or hit an unexpected error (`internal`: the log has the stack trace).

## Logs

| What | Log group |
| ---- | --------- |
| Lambda | `/aws/lambda/<project>-<env>-info` |
| API access | `/aws/apigateway/<project>-<env>-info/access` |
| VPC flow | `/aws/vpc/<project>-<env>/flow-logs` |
| Database | `/aws/rds/instance/<project>-<env>-db/postgresql` and `.../upgrade` |

```bash
make logs                                                    # Lambda, last 15 minutes, following
aws logs tail <log-group> --since 1h --filter-pattern '"database unavailable"'
```

Three queries are saved in CloudWatch Logs Insights under `<project>-<env>/`:
recent warnings and errors, database failures by category, and API latency
percentiles. All three were executed against real CloudWatch logs during the
`dev` deployment ([evidence/dev-us-east-1.md](evidence/dev-us-east-1.md)), with
`api-latency-percentiles` returning `requests`, `avg_ms` and `p99_ms` (and the
two error queries returning `0` rows on the healthy stack).

## Alarms

All alarms publish to the `<project>-<env>-alerts` topic and notify again on
recovery. Set `alert_email` to subscribe; AWS sends a confirmation link that must
be clicked before anything is delivered.

| Alarm | What to do |
| ----- | ---------- |
| `rds-cpu-high`, `rds-memory-low` | Look at slow statements in the database log; consider a larger instance class |
| `rds-storage-low` | Storage autoscaling has reached its ceiling: raise `db_max_allocated_storage` |
| `rds-connections-high` | Check Lambda concurrency and the throttle; see [architecture](architecture.md#capacity-and-timeouts) |
| `lambda-errors` | The function failed outright: read its log |
| `lambda-throttles` | The concurrency cap was reached: the database is slow or traffic is high |
| `lambda-duration-p99` | Close to timing out: check database latency |
| `api-5xx` | Includes the handled `503` when the database is down; read `database.error` |
| `nat-port-allocation-<n>` | Too many concurrent connections through one NAT gateway |

If the instance class changes, revisit `db_connections_alarm_threshold`: it should
be about 75% of `max_connections` (`SHOW max_connections;`).

## Password rotation

RDS rotates the master password every seven days and updates the secret. The
function caches it for five minutes; after a rejected login it drops the cache and
retries once with the new value, so rotation causes no failed requests.

To rotate now (the secret ARN is the `DB_SECRET_ARN` variable of the function):

```bash
aws secretsmanager rotate-secret --secret-id <SECRET_ARN> --rotate-immediately
```

## Backups and recovery

Automated backups run daily and keep transaction logs, so the database can be
restored to any second inside the retention window (7 days in dev, 14 in prod).
Restoring always creates a new instance:

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier <project>-<env>-db \
  --target-db-instance-identifier <project>-<env>-db-restored \
  --use-latest-restorable-time        # or --restore-time <ISO-8601 UTC>
```

Check the restored data first. Then either point the function at it (a code
change, because `DB_HOST` is wired from the database module) or import it into
state and retire the old instance.

Known gap: the database module cannot yet build an instance from a snapshot
(`snapshot_identifier` is not exposed), so recovery into the Terraform-managed
instance itself is manual. Add the variable when a restore procedure is needed in
anger. A final snapshot is taken on deletion when `db_skip_final_snapshot` is
false, which is the default and what prod uses.

## Changing things

| Change | Effect |
| ------ | ------ |
| Instance class or engine version | May restart the database. With `db_apply_immediately = false` it waits for the maintenance window (Sunday 05:00 UTC by default) |
| Storage ceiling | Applies without a restart |
| `db_multi_az` | Creates a standby; brief performance impact while it syncs |
| Lambda memory, timeout, concurrency | Applies to the next invocation |
| Throttle limits | Applies to the stage at once |
| `nat_gateway_mode` | Creates or removes NAT gateways and changes the app route tables |

Always read the plan: `make plan ENV=<env>` saves it, `make apply ENV=<env>`
applies exactly that.

## Tearing down

```bash
make destroy ENV=dev REGION=us-east-1 CONFIRM=dev
```

Terraform still asks for confirmation. Things to know:

- **Deletion protection.** Prod has it on, so `destroy` fails until
  `db_deletion_protection = false` is applied. That is the point.
- **Network interfaces.** Lambda releases its interfaces in the VPC some time
  after the function is deleted. If deleting a subnet or security group fails
  with a dependency error, wait and run `destroy` again. How long this takes was
  not measured.
- **Snapshots.** If a final snapshot was taken, it stays and bills until you
  delete it.
- **KMS keys** are scheduled for deletion and stay recoverable for the configured
  window (7 days in dev, 30 by default), then disappear.
- **The state bucket** is not destroyed (`prevent_destroy`). Empty and remove it by
  hand when no environment uses it.

## First deployment problems

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| `make init` says to set `STATE_BUCKET` | The bootstrap bucket was not created, or was created on another machine | Run `make bootstrap-plan` and `bootstrap-apply`, or set `STATE_BUCKET` and `STATE_REGION` |
| Terraform says the state is locked | A run was interrupted | `make unlock ENV=<env> REGION=<region> CONFIRM=<env> LOCK_ID=<id from the error>` |
| Terraform refuses the account | `allowed_account_ids` does not include the active account | Fix the profile or the list |
| Bucket name already exists | S3 bucket names are global | Choose another `BUCKET` |
| Apply fails because unreserved concurrency would fall below its minimum | The account's Lambda quota is too small to reserve any | Leave `lambda_reserved_concurrency` at -1 (the dev default) |
| `make verify` returns `503` right after apply | The database was still starting, or the NAT gateway was not ready | Wait a minute and retry; read `database.error` |
| No alert emails arrive | The subscription is unconfirmed | Click the link AWS emailed |
