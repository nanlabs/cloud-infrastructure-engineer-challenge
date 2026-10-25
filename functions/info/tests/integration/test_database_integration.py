"""Runs against a real PostgreSQL, configured through the DB_* environment variables.

Set DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD and DB_SSL_MODE=disable to
point at any PostgreSQL, then run: make function-integration
Without DB_HOST the whole module is skipped.
"""

import json
import os
import re
from types import SimpleNamespace

import pytest

from info_api import handler
from info_api.config import Settings
from info_api.credentials import CredentialsProvider
from info_api.database import Database, DatabaseError

pytestmark = [
    pytest.mark.integration,
    pytest.mark.skipif(not os.environ.get("DB_HOST"), reason="DB_HOST is not set"),
]


@pytest.fixture
def env():
    keys = ("DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD", "DB_SSL_MODE")
    return {key: os.environ[key] for key in keys if key in os.environ}


@pytest.fixture
def database(env):
    settings = Settings.from_env(env)
    database = Database(settings, CredentialsProvider(settings))
    yield database
    database.close()


def test_probe_reads_real_server_state(database, env):
    status = database.probe()

    assert re.match(r"^\d+\.\d+", status.version)
    assert status.database == env["DB_NAME"]
    assert status.in_recovery is False
    assert status.uptime_seconds >= 0
    assert status.latency_ms > 0


def test_probe_reports_whether_the_session_uses_tls(database, env):
    status = database.probe()

    assert status.tls is (env.get("DB_SSL_MODE", "verify-full") != "disable")


def test_statement_timeout_is_applied_to_the_session(database):
    database.probe()

    # Private access on purpose: the setting is only visible from the session.
    assert database._conn.run("SHOW statement_timeout")[0][0] == "2s"


def test_the_same_connection_serves_repeated_probes(database):
    database.probe()
    first = database._conn

    database.probe()

    assert database._conn is first


def test_a_wrong_password_is_reported_as_authentication(env):
    settings = Settings.from_env({**env, "DB_PASSWORD": "definitely-not-the-password"})
    database = Database(settings, CredentialsProvider(settings))

    with pytest.raises(DatabaseError) as raised:
        database.probe()

    assert raised.value.category == "authentication"


def test_a_closed_port_is_reported_as_unavailable(env):
    settings = Settings.from_env({**env, "DB_PORT": "1"})
    database = Database(settings, CredentialsProvider(settings))

    with pytest.raises(DatabaseError) as raised:
        database.probe()

    assert raised.value.category == "unavailable"


def test_the_handler_answers_end_to_end(monkeypatch, env):
    for key, value in env.items():
        monkeypatch.setenv(key, value)
    monkeypatch.setattr(handler, "_app", None)
    monkeypatch.setattr(handler, "_cold_start", True)

    response = handler.lambda_handler({}, SimpleNamespace(aws_request_id="req-it"))
    body = json.loads(response["body"])

    assert response["statusCode"] == 200
    assert body["database"]["connected"] is True
    assert body["database"]["database"] == env["DB_NAME"]
    assert body["instance"] is None
