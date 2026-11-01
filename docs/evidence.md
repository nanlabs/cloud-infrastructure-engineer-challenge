# Deployment evidence

Captured from a real deployment of this stack in `us-east-1` on 2026-11-01 (Terraform 1.14.9, AWS provider 6.71.0, default variables plus `alarm_email`). The AWS account ID, client IP addresses and the alarm email are redacted.

- [1. Deployment](#1-deployment)
- [2. GET /info through CloudFront](#2-get-info-through-cloudfront)
- [3. CloudWatch Logs](#3-cloudwatch-logs)
- [4. Database](#4-database)
- [5. Network isolation](#5-network-isolation)
- [6. Alarms](#6-alarms)
- [7. Multi-AZ failover test](#7-multi-az-failover-test)

## 1. Deployment

```text
$ python scripts/build_lambda.py
Lambda package ready in lambda\build

$ terraform -chdir=terraform plan -out=tfplan
Plan: 54 to add, 0 to change, 0 to destroy.

$ terraform -chdir=terraform apply tfplan
module.network.aws_nat_gateway.this[0]: Creation complete after 1m47s
module.cloudfront.aws_cloudfront_distribution.this: Creation complete after 2m47s
module.lambda.aws_lambda_function.this: Creation complete after 3m49s
module.database.aws_db_instance.this: Creation complete after 15m47s
Apply complete! Resources: 54 added, 0 changed, 0 destroyed.

$ terraform -chdir=terraform output
api_access_log_group       = "/aws/apigateway/nanlabs-challenge-dev/access-logs"
api_gateway_info_url       = "https://kegzt1ns80.execute-api.us-east-1.amazonaws.com/info"
cloudfront_distribution_id = "E3C15DCFAA24SI"
info_url                   = "https://dbi0mpculidu4.cloudfront.net/info"
lambda_function_name       = "nanlabs-challenge-dev-info"
lambda_log_group           = "/aws/lambda/nanlabs-challenge-dev-info"
vpc_id                     = "vpc-0cea2603152650d1d"
```

The Multi-AZ RDS instance (primary plus synchronous standby) accounts for most of the ~20 minutes; the Lambda takes ~4 minutes because AWS attaches its network interfaces to the private subnets.

## 2. GET /info through CloudFront

```text
$ curl -i https://dbi0mpculidu4.cloudfront.net/info
HTTP/1.1 200 OK
Content-Type: application/json
cache-control: no-store
X-Cache: Miss from cloudfront
Via: 1.1 577ac6ab40b1e229d1caa3dc0fac8dba.cloudfront.net (CloudFront)
X-Amz-Cf-Pop: MIA3-P2
Alt-Svc: h3=":443"; ma=86400
X-XSS-Protection: 1; mode=block
X-Frame-Options: SAMEORIGIN
Referrer-Policy: strict-origin-when-cross-origin
X-Content-Type-Options: nosniff
Strict-Transport-Security: max-age=31536000
```

```json
{
  "service": "info",
  "timestamp": "2026-11-01T21:52:32+00:00",
  "request_id": "533cef29-fcf2-4193-b9c0-6895fe4aaf65",
  "database": {
    "engine": "postgresql",
    "instance_class": "db.t4g.micro",
    "multi_az": true,
    "version": "PostgreSQL 17.9 on aarch64-unknown-linux-gnu, compiled by aarch64-unknown-linux-gnu-gcc (GCC) 12.4.0, 64-bit",
    "server_version": "17.9",
    "database": "app",
    "uptime_seconds": 935,
    "ssl": true,
    "status": "connected",
    "latency_ms": 2248.2
  }
}
```

- `"ssl": true` is read from `pg_stat_ssl` for the Lambda's own session; the client also verified the server certificate against the RDS CA bundle.
- The security headers come from the CloudFront managed `SecurityHeadersPolicy`; `X-Cache: Miss` on every call because caching is disabled on purpose.
- `latency_ms` is 2248 ms on the first (cold) call, which also reads the secret from Secrets Manager through the NAT Gateway; warm calls take 110-135 ms (new TLS connection per request).

Plain HTTP is redirected, and the API Gateway endpoint answers the same payload directly:

```text
$ curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" http://dbi0mpculidu4.cloudfront.net/info
301 https://dbi0mpculidu4.cloudfront.net/info

$ curl -i https://kegzt1ns80.execute-api.us-east-1.amazonaws.com/info
HTTP/1.1 200 OK
Content-Type: application/json
cache-control: no-store
Apigw-Requestid: GLkpfglmIAMEZhw=

{"service": "info", "timestamp": "2026-11-01T21:52:34+00:00", "request_id": "9d944549-704c-4e47-a99b-bf80ea33a9a1", "database": {"engine": "postgresql", ..., "ssl": true, "status": "connected", "latency_ms": 112.5}}
```

## 3. CloudWatch Logs

Lambda function, one structured JSON line per invocation (`requestId` matches the `request_id` returned to the client):

```text
$ aws logs filter-log-events --log-group-name /aws/lambda/nanlabs-challenge-dev-info --query 'events[].message' --output text
{"timestamp": "2026-11-01T21:52:32Z", "level": "INFO", "message": "Database health check", "logger": "root", "requestId": "533cef29-fcf2-4193-b9c0-6895fe4aaf65", "db_status": "connected", "latency_ms": 2248.2}
{"timestamp": "2026-11-01T21:52:33Z", "level": "INFO", "message": "Database health check", "logger": "root", "requestId": "8081a229-7ce1-4788-9aff-abe23e55ac56", "db_status": "connected", "latency_ms": 132.7}
{"timestamp": "2026-11-01T21:52:34Z", "level": "INFO", "message": "Database health check", "logger": "root", "requestId": "9d944549-704c-4e47-a99b-bf80ea33a9a1", "db_status": "connected", "latency_ms": 112.5}
```

API Gateway access log:

```text
$ aws logs filter-log-events --log-group-name /aws/apigateway/nanlabs-challenge-dev/access-logs --query 'events[].message' --output text
{"httpMethod":"GET","integrationError":"-","integrationLatency":"125","requestId":"GLkpfglmIAMEZhw=","requestTime":"01/Nov/2026:21:52:34 +0000","responseLatency":"130","responseLength":"453","routeKey":"GET /info","sourceIp":"<redacted>","status":"200","userAgent":"curl/8.18.0"}
```

## 4. Database

```text
$ aws rds describe-db-instances --db-instance-identifier nanlabs-challenge-dev-postgres --query 'DBInstances[0].{...}' --output table
+-----------------------+-----------------------------+
|  BackupRetentionDays  |  7                          |
|  Class                |  db.t4g.micro               |
|  Engine               |  postgres                   |
|  LatestRestorableTime |  2026-11-01T21:46:58+00:00  |
|  LogExports           |  postgresql                 |
|  MultiAZ              |  True                       |
|  PrimaryAZ            |  us-east-1a                 |
|  PubliclyAccessible   |  False                      |
|  StandbyAZ            |  us-east-1b                 |
|  StorageEncrypted     |  True                       |
|  StorageType          |  gp3                        |
|  Version              |  17.9                       |
+-----------------------+-----------------------------+
```

`LatestRestorableTime` shows point-in-time recovery is active from the first automated backup.

## 5. Network isolation

The Lambda runs only in the private subnets:

```text
$ aws lambda get-function-configuration --function-name nanlabs-challenge-dev-info --query '{...}' --output table
|  Arch     |  arm64                                               |
|  LogFormat|  JSON                                                |
|  Runtime  |  python3.13                                          |
|  SG       |  sg-08d9ee961f78dde5b                                |
|  Subnets  |  subnet-052fdd313c11dec92,subnet-036d9808e97af07cb   |
```

```text
$ aws ec2 describe-subnets --filters Name=vpc-id,Values=vpc-0cea2603152650d1d --query '...' --output table
|  Name                                      |  Subnet ID                |  CIDR         |  AZ         |  Public IP on launch |
|  nanlabs-challenge-dev-public-us-east-1a   |  subnet-0ebfc0896ce6ad922 |  10.0.0.0/24  |  us-east-1a |  False               |
|  nanlabs-challenge-dev-public-us-east-1b   |  subnet-00e04f85ba6b3b7e7 |  10.0.1.0/24  |  us-east-1b |  False               |
|  nanlabs-challenge-dev-private-us-east-1a  |  subnet-052fdd313c11dec92 |  10.0.10.0/24 |  us-east-1a |  False               |
|  nanlabs-challenge-dev-private-us-east-1b  |  subnet-036d9808e97af07cb |  10.0.11.0/24 |  us-east-1b |  False               |
|  nanlabs-challenge-dev-database-us-east-1a |  subnet-025571b43b2a93e8f |  10.0.20.0/24 |  us-east-1a |  False               |
|  nanlabs-challenge-dev-database-us-east-1b |  subnet-0c35472bba7f630fb |  10.0.21.0/24 |  us-east-1b |  False               |
```

Route tables: only the public tier reaches the Internet Gateway, the private tier goes out through the NAT Gateway, and the database tier has no route outside the VPC.

```text
$ aws ec2 describe-route-tables --filters Name=vpc-id,Values=vpc-0cea2603152650d1d --query '...' --output table
|  nanlabs-challenge-dev-public             |  10.0.0.0/16 -> local | 0.0.0.0/0 -> igw-08051f427322a1492  |
|  nanlabs-challenge-dev-private-us-east-1a |  10.0.0.0/16 -> local | 0.0.0.0/0 -> nat-0097e35ff27da44f5  |
|  nanlabs-challenge-dev-private-us-east-1b |  10.0.0.0/16 -> local | 0.0.0.0/0 -> nat-0097e35ff27da44f5  |
|  nanlabs-challenge-dev-database           |  10.0.0.0/16 -> local                                     |
|  (VPC main table, no subnets associated)  |  10.0.0.0/16 -> local                                     |
```

## 6. Alarms

All alarms created and in `OK` right after the deployment:

```text
$ aws cloudwatch describe-alarms --alarm-name-prefix nanlabs-challenge-dev --query 'MetricAlarms[].[...]' --output table
|  nanlabs-challenge-dev-api-5xx              |  OK |  AWS/ApiGateway |  5xx                 |  GreaterThanThreshold |  0.0           |
|  nanlabs-challenge-dev-lambda-errors        |  OK |  AWS/Lambda     |  Errors              |  GreaterThanThreshold |  0.0           |
|  nanlabs-challenge-dev-lambda-throttles     |  OK |  AWS/Lambda     |  Throttles           |  GreaterThanThreshold |  0.0           |
|  nanlabs-challenge-dev-rds-connections-high |  OK |  AWS/RDS        |  DatabaseConnections |  GreaterThanThreshold |  50.0          |
|  nanlabs-challenge-dev-rds-cpu-high         |  OK |  AWS/RDS        |  CPUUtilization      |  GreaterThanThreshold |  80.0          |
|  nanlabs-challenge-dev-rds-free-storage-low |  OK |  AWS/RDS        |  FreeStorageSpace    |  LessThanThreshold    |  2147483648.0  |
```

The email subscription to the alarms topic was confirmed; section 7 shows an alarm firing and recovering through it.

## 7. Multi-AZ failover test

A forced failover of the RDS instance while a client called `GET /info` through CloudFront every ~5 seconds for 7 minutes. Times in UTC.

```text
$ aws rds reboot-db-instance --db-instance-identifier nanlabs-challenge-dev-postgres --force-failover
22:11:53  requested (primary us-east-1a, standby us-east-1b)
```

What the client saw:

```text
22:11:51  HTTP 200  status=connected    latency_ms=140.6  uptime_s=2095
22:11:57  HTTP 200  status=connected    latency_ms=128.6  uptime_s=2101
22:12:03  HTTP 503  status=unreachable  latency_ms=56.9   error=InterfaceError
22:12:09  HTTP 503  status=unreachable  latency_ms=60.7   error=InterfaceError
22:12:15  HTTP 200  status=connected    latency_ms=204.2  uptime_s=0
22:12:21  HTTP 200  status=connected    latency_ms=115.5  uptime_s=6
...       HTTP 200 on every call until the end of the test (22:18:27)
```

RDS events and the instance afterwards:

```text
$ aws rds describe-events --source-identifier nanlabs-challenge-dev-postgres --source-type db-instance
22:12:00  Multi-AZ instance failover started.
22:12:18  DB instance restarted
22:13:00  Multi-AZ instance failover completed

$ aws rds describe-db-instances --db-instance-identifier nanlabs-challenge-dev-postgres --query 'DBInstances[0].[DBInstanceStatus,AvailabilityZone,SecondaryAvailabilityZone]'
available  us-east-1b  us-east-1a
```

The Lambda logged the failure with its stack trace, while the client only received the error type (fields trimmed):

```text
{"timestamp": "2026-11-01T22:12:03Z", "level": "ERROR", "message": "Database health check failed", "errorType": "InterfaceError", "errorMessage": "Can't create a connection to host nanlabs-challenge-dev-postgres.c4fkqsyw6dd2.us-east-1.rds.amazonaws.com and port 5432 (timeout is 5 and source_address is None).", "requestId": "3c74dc44-7392-4357-b24c-f67f4a320c85", "stackTrace": ["..."]}
{"timestamp": "2026-11-01T22:12:03Z", "level": "INFO", "message": "Database health check", "requestId": "3c74dc44-7392-4357-b24c-f67f4a320c85", "db_status": "unreachable", "latency_ms": 56.9}
```

The `api-5xx` alarm fired on the two `503` responses and recovered on its own, notifying the SNS topic both times:

```text
$ aws cloudwatch describe-alarm-history --alarm-name nanlabs-challenge-dev-api-5xx
22:13:58  Alarm updated from OK to ALARM
22:13:58  Successfully executed action arn:aws:sns:us-east-1:<account-id>:nanlabs-challenge-dev-alarms
22:18:58  Alarm updated from ALARM to OK
22:18:58  Successfully executed action arn:aws:sns:us-east-1:<account-id>:nanlabs-challenge-dev-alarms
```

Both notifications arrived by email: `ALARM` ("1 datapoint [2.0 (01/11/26 22:08:00)] was greater than the threshold (0.0)", the two `503` responses) and `OK` five minutes later.

Result: the standby in the other AZ took over with no manual action and no configuration change (same endpoint name). Clients saw two failed calls; the outage lasted less than 18 seconds (between the last `200` before and the first `200` after). The `lambda-errors` alarm stayed `OK` because the function handled the outage and answered `503` instead of failing.
