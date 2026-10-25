import ssl

import pg8000.exceptions
import pytest

from info_api.credentials import Credentials, CredentialsError
from info_api.database import Database, DatabaseError

ROW = ("17.4", "appdb", False, 3600, True)


class FakeCredentials:
    def __init__(self, error: Exception | None = None) -> None:
        self.error = error
        self.invalidations = 0

    def get(self) -> Credentials:
        if self.error:
            raise self.error
        return Credentials(username="dbadmin", password="secret")

    def invalidate(self) -> None:
        self.invalidations += 1


class FakeConnection:
    def __init__(self, rows=None, error: Exception | None = None) -> None:
        self.rows = [ROW] if rows is None else rows
        self.error = error
        self.closed = False

    def run(self, sql):
        if self.error:
            raise self.error
        return self.rows

    def close(self):
        self.closed = True


class FakeConnect:
    """Hands out the queued connections, or raises the queued exceptions."""

    def __init__(self, *outcomes) -> None:
        self.outcomes = list(outcomes)
        self.calls: list[dict] = []

    def __call__(self, **kwargs):
        self.calls.append(kwargs)
        outcome = self.outcomes.pop(0)
        if isinstance(outcome, Exception):
            raise outcome
        return outcome


def pg_error(code: str) -> pg8000.exceptions.DatabaseError:
    return pg8000.exceptions.DatabaseError({"S": "FATAL", "C": code, "M": "detail not for callers"})


def make_database(make_settings, connect, credentials=None, **env):
    settings = make_settings(DB_SSL_MODE="disable", **env)
    return Database(settings, credentials or FakeCredentials(), connect=connect)


def test_probe_reports_the_server_state(make_settings):
    database = make_database(make_settings, FakeConnect(FakeConnection()))

    status = database.probe()

    assert status.version == "17.4"
    assert status.database == "appdb"
    assert status.in_recovery is False
    assert status.uptime_seconds == 3600
    assert status.tls is True
    assert status.latency_ms >= 0


def test_the_connection_is_reused_across_probes(make_settings):
    connect = FakeConnect(FakeConnection())
    database = make_database(make_settings, connect)

    database.probe()
    database.probe()

    assert len(connect.calls) == 1


def test_connection_uses_the_configured_target_and_limits(make_settings):
    connect = FakeConnect(FakeConnection())
    database = make_database(make_settings, connect, DB_PORT="5433", DB_STATEMENT_TIMEOUT_MS="1500")

    database.probe()

    call = connect.calls[0]
    assert call["host"] == "db.internal.example"
    assert call["port"] == 5433
    assert call["database"] == "appdb"
    assert call["timeout"] == 3.0
    assert call["startup_params"] == {"statement_timeout": "1500"}


def test_a_stale_connection_is_replaced_once(make_settings):
    stale = FakeConnection()
    fresh = FakeConnection()
    connect = FakeConnect(stale, fresh)
    database = make_database(make_settings, connect)
    database.probe()
    stale.error = pg8000.exceptions.InterfaceError("network error")

    status = database.probe()

    assert status.database == "appdb"
    assert stale.closed
    assert len(connect.calls) == 2


def test_a_failing_fresh_connection_is_not_retried(make_settings):
    connect = FakeConnect(OSError("connection refused"))
    database = make_database(make_settings, connect)

    with pytest.raises(DatabaseError) as raised:
        database.probe()

    assert raised.value.category == "unavailable"
    assert len(connect.calls) == 1


def test_a_rotated_password_is_picked_up_with_one_retry(make_settings):
    credentials = FakeCredentials()
    connect = FakeConnect(pg_error("28P01"), FakeConnection())
    database = make_database(make_settings, connect, credentials)

    status = database.probe()

    assert status.database == "appdb"
    assert credentials.invalidations == 1
    assert len(connect.calls) == 2


def test_a_wrong_password_fails_after_a_single_retry(make_settings):
    credentials = FakeCredentials()
    connect = FakeConnect(pg_error("28P01"), pg_error("28P01"))
    database = make_database(make_settings, connect, credentials)

    with pytest.raises(DatabaseError) as raised:
        database.probe()

    assert raised.value.category == "authentication"
    assert len(connect.calls) == 2


@pytest.mark.parametrize(
    ("error", "category"),
    [
        (TimeoutError("timed out"), "timeout"),
        (pg_error("57014"), "timeout"),
        (ssl.SSLCertVerificationError("certificate verify failed"), "tls"),
        (pg8000.exceptions.InterfaceError("Server refuses SSL"), "tls"),
        (pg_error("53300"), "unavailable"),
        (OSError("no route to host"), "unavailable"),
    ],
)
def test_failures_are_mapped_to_a_safe_category(make_settings, error, category):
    database = make_database(make_settings, FakeConnect(error))

    with pytest.raises(DatabaseError) as raised:
        database.probe()

    assert raised.value.category == category
    assert "detail not for callers" not in str(raised.value)


def test_unreadable_credentials_are_their_own_category(make_settings):
    credentials = FakeCredentials(error=CredentialsError("secret could not be read"))
    database = make_database(make_settings, FakeConnect(), credentials)

    with pytest.raises(DatabaseError) as raised:
        database.probe()

    assert raised.value.category == "credentials"


def test_tls_verifies_the_certificate_and_hostname(make_settings):
    connect = FakeConnect(FakeConnection())
    database = Database(make_settings(), FakeCredentials(), connect=connect)

    database.probe()

    context = connect.calls[0]["ssl_context"]
    assert context.verify_mode == ssl.CERT_REQUIRED
    assert context.check_hostname is True


def test_tls_can_be_disabled_only_explicitly(make_settings):
    connect = FakeConnect(FakeConnection())
    database = make_database(make_settings, connect)

    database.probe()

    assert connect.calls[0]["ssl_context"] is None
