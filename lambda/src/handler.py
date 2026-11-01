"""GET /info: reports the connection status and basic metadata of the PostgreSQL backend.

Configuration (environment variables):
  DB_HOST, DB_PORT, DB_NAME      connection target
  DB_SECRET_ARN                  Secrets Manager secret with {"username", "password"} (AWS)
  DB_USER, DB_PASSWORD           plain credentials when DB_SECRET_ARN is unset (local Docker)
  DB_SSL                         "true" (default) verifies the server cert with the RDS CA bundle
  DB_CONNECT_TIMEOUT             seconds, default 5
  DB_INSTANCE_CLASS, DB_MULTI_AZ metadata injected by Terraform
"""

import json
import logging
import os
import ssl
import time
from datetime import UTC, datetime
from pathlib import Path

import pg8000.native

logger = logging.getLogger()
# Lambda exports the level configured in logging_config; default to INFO elsewhere (local runs)
logger.setLevel(os.environ.get("AWS_LAMBDA_LOG_LEVEL", "INFO"))

RDS_CA_BUNDLE = Path(__file__).with_name("rds-ca-bundle.pem")
AUTH_FAILED_SQLSTATE = "28P01"

# Reused across warm invocations; refreshed when RDS rotates the secret
_cached_credentials = None


def _get_credentials(force_refresh=False):
    global _cached_credentials

    secret_arn = os.environ.get("DB_SECRET_ARN")
    if not secret_arn:
        return os.environ["DB_USER"], os.environ["DB_PASSWORD"]

    if _cached_credentials is None or force_refresh:
        import boto3  # bundled in the Lambda runtime; not needed for local runs

        response = boto3.client("secretsmanager").get_secret_value(SecretId=secret_arn)
        secret = json.loads(response["SecretString"])
        _cached_credentials = (secret["username"], secret["password"])
    return _cached_credentials


def _ssl_context():
    if os.environ.get("DB_SSL", "true").lower() != "true":
        return None
    # Verifies the certificate chain and that the hostname matches the RDS endpoint
    return ssl.create_default_context(cafile=str(RDS_CA_BUNDLE))


def _query_database(user, password):
    connection = pg8000.native.Connection(
        user=user,
        password=password,
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "5432")),
        database=os.environ["DB_NAME"],
        ssl_context=_ssl_context(),
        timeout=int(os.environ.get("DB_CONNECT_TIMEOUT", "5")),
    )
    try:
        version, server_version, database, uptime, ssl_in_use = connection.run(
            """
            SELECT version(),
                   current_setting('server_version'),
                   current_database(),
                   EXTRACT(EPOCH FROM now() - pg_postmaster_start_time())::int,
                   COALESCE((SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()), false)
            """
        )[0]
    finally:
        connection.close()

    return {
        "version": version,
        "server_version": server_version,
        "database": database,
        "uptime_seconds": uptime,
        "ssl": ssl_in_use,
    }


def _check_database():
    user, password = _get_credentials()
    try:
        return _query_database(user, password)
    except pg8000.native.DatabaseError as exc:
        error = exc.args[0] if exc.args and isinstance(exc.args[0], dict) else {}
        if error.get("C") != AUTH_FAILED_SQLSTATE or not os.environ.get("DB_SECRET_ARN"):
            raise
        # The cached secret is stale (RDS rotated it): fetch it again and retry once
        logger.warning("Database authentication failed, refreshing credentials")
        user, password = _get_credentials(force_refresh=True)
        return _query_database(user, password)


def lambda_handler(event, context):
    started = time.perf_counter()
    database = {
        "engine": "postgresql",
        "instance_class": os.environ.get("DB_INSTANCE_CLASS", "unknown"),
        "multi_az": os.environ.get("DB_MULTI_AZ", "false").lower() == "true",
    }

    try:
        database.update(_check_database())
        database["status"] = "connected"
        status_code = 200
    except Exception as exc:  # the endpoint reports backend health instead of failing
        logger.exception("Database health check failed")
        database["status"] = "unreachable"
        database["error"] = type(exc).__name__
        status_code = 503

    database["latency_ms"] = round((time.perf_counter() - started) * 1000, 1)
    logger.info(
        "Database health check",
        extra={"db_status": database["status"], "latency_ms": database["latency_ms"]},
    )

    body = {
        "service": "info",
        "timestamp": datetime.now(UTC).isoformat(timespec="seconds"),
        "request_id": getattr(context, "aws_request_id", None),
        "database": database,
    }
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json", "Cache-Control": "no-store"},
        "body": json.dumps(body),
    }
