from __future__ import annotations

import logging
import ssl
import time
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

import pg8000.exceptions
import pg8000.native

from info_api.config import Settings
from info_api.credentials import CredentialsError, CredentialsProvider

logger = logging.getLogger(__name__)

AUTHENTICATION = "authentication"
CREDENTIALS = "credentials"
TIMEOUT = "timeout"
TLS = "tls"
UNAVAILABLE = "unavailable"

# SQLSTATE codes: invalid_password, invalid_authorization_specification,
# query_canceled (raised by statement_timeout).
_AUTH_CODES = {"28P01", "28000"}
_TIMEOUT_CODES = {"57014"}

PROBE_SQL = """
SELECT
    current_setting('server_version'),
    current_database(),
    pg_is_in_recovery(),
    EXTRACT(EPOCH FROM (now() - pg_postmaster_start_time()))::bigint,
    COALESCE((SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()), false)
"""


class DatabaseError(Exception):
    """A probe failed. category is safe to show to callers; the cause is not."""

    def __init__(self, category: str) -> None:
        super().__init__(category)
        self.category = category


@dataclass(frozen=True)
class DbStatus:
    version: str
    database: str
    in_recovery: bool
    uptime_seconds: int
    tls: bool
    latency_ms: float


class Database:
    """One PostgreSQL connection, reused across warm invocations."""

    def __init__(
        self,
        settings: Settings,
        credentials: CredentialsProvider,
        connect: Callable[..., Any] = pg8000.native.Connection,
    ) -> None:
        self._settings = settings
        self._credentials = credentials
        self._connect = connect
        self._conn: Any | None = None

    def probe(self) -> DbStatus:
        reused = self._conn is not None
        try:
            return self._probe_once()
        except DatabaseError as exc:
            self.close()
            if exc.category == AUTHENTICATION:
                self._credentials.invalidate()
            elif not (reused and exc.category == UNAVAILABLE):
                raise
            # The password may have rotated, or a reused connection may have
            # gone stale (idle timeout, failover): one fresh attempt.
            return self._probe_once()

    def close(self) -> None:
        conn, self._conn = self._conn, None
        if conn is not None:
            try:
                conn.close()
            except Exception:
                logger.debug("closing a broken connection failed", exc_info=True)

    def _probe_once(self) -> DbStatus:
        try:
            conn = self._conn or self._open()
            self._conn = conn
            started = time.perf_counter()
            row = conn.run(PROBE_SQL)[0]
            latency_ms = (time.perf_counter() - started) * 1000
        except DatabaseError:
            raise
        except Exception as exc:
            category = _categorize(exc)
            logger.warning(
                "database probe failed",
                extra={"category": category, "error_type": type(exc).__name__},
            )
            raise DatabaseError(category) from exc

        return DbStatus(
            version=str(row[0]),
            database=str(row[1]),
            in_recovery=bool(row[2]),
            uptime_seconds=int(row[3]),
            tls=bool(row[4]),
            latency_ms=round(latency_ms, 1),
        )

    def _open(self) -> Any:
        try:
            credentials = self._credentials.get()
        except CredentialsError as exc:
            raise DatabaseError(CREDENTIALS) from exc

        return self._connect(
            user=credentials.username,
            password=credentials.password,
            host=self._settings.db_host,
            port=self._settings.db_port,
            database=self._settings.db_name,
            ssl_context=self._ssl_context(),
            timeout=self._settings.connect_timeout_s,
            startup_params={"statement_timeout": str(self._settings.statement_timeout_ms)},
            application_name="info-api",
        )

    def _ssl_context(self) -> ssl.SSLContext | None:
        if self._settings.ssl_mode == "disable":
            return None
        # create_default_context verifies the certificate chain and the hostname.
        return ssl.create_default_context(cafile=str(self._settings.ca_bundle))


def _categorize(exc: Exception) -> str:
    if isinstance(exc, ssl.SSLError):
        return TLS
    if isinstance(exc, TimeoutError):
        return TIMEOUT
    if isinstance(exc, pg8000.exceptions.DatabaseError):
        detail = exc.args[0] if exc.args and isinstance(exc.args[0], dict) else {}
        code = detail.get("C")
        if code in _AUTH_CODES:
            return AUTHENTICATION
        if code in _TIMEOUT_CODES:
            return TIMEOUT
        return UNAVAILABLE
    if isinstance(exc, pg8000.exceptions.InterfaceError) and "SSL" in str(exc):
        return TLS
    return UNAVAILABLE
