import json
from types import SimpleNamespace

import pytest

from info_api import handler
from info_api.config import ConfigError
from info_api.database import DatabaseError, DbStatus

STATUS = DbStatus(
    version="17.4",
    database="appdb",
    in_recovery=False,
    uptime_seconds=3600,
    tls=True,
    latency_ms=4.2,
)
INSTANCE = {"class": "db.t4g.micro", "multi_az": False, "status": "available"}
CONTEXT = SimpleNamespace(aws_request_id="req-123")


class FakeDatabase:
    def __init__(self, outcome) -> None:
        self.outcome = outcome

    def probe(self):
        if isinstance(self.outcome, Exception):
            raise self.outcome
        return self.outcome


class FakeMetadata:
    def get(self):
        return INSTANCE


@pytest.fixture(autouse=True)
def fresh_module_state(monkeypatch):
    monkeypatch.setattr(handler, "_app", None)
    monkeypatch.setattr(handler, "_cold_start", True)


def install(monkeypatch, outcome):
    app = handler.App(FakeDatabase(outcome), FakeMetadata(), region="us-east-1")
    monkeypatch.setattr(handler, "_build_app", lambda: app)


def call():
    response = handler.lambda_handler({}, CONTEXT)
    return response, json.loads(response["body"])


def test_success_returns_status_and_instance_details(monkeypatch):
    install(monkeypatch, STATUS)

    response, body = call()

    assert response["statusCode"] == 200
    assert response["headers"]["content-type"] == "application/json"
    assert response["headers"]["cache-control"] == "no-store"
    assert body["status"] == "ok"
    assert body["request_id"] == "req-123"
    assert body["database"] == {
        "connected": True,
        "engine": "postgres",
        "version": "17.4",
        "database": "appdb",
        "in_recovery": False,
        "uptime_seconds": 3600,
        "tls": True,
        "latency_ms": 4.2,
    }
    assert body["instance"] == INSTANCE
    assert body["runtime"] == {"region": "us-east-1", "cold_start": True}


def test_only_the_first_invocation_is_a_cold_start(monkeypatch):
    install(monkeypatch, STATUS)

    _, first = call()
    _, second = call()

    assert first["runtime"]["cold_start"] is True
    assert second["runtime"]["cold_start"] is False


def test_an_unreachable_database_is_a_503_with_a_category_only(monkeypatch):
    install(monkeypatch, DatabaseError("timeout"))

    response, body = call()

    assert response["statusCode"] == 503
    assert body["status"] == "degraded"
    assert body["database"] == {"connected": False, "error": "timeout"}
    assert "instance" not in body


def test_error_bodies_never_contain_connection_details(monkeypatch):
    install(monkeypatch, DatabaseError("unavailable"))

    response, _ = call()

    for secret in ("db.internal.example", "dbadmin", "password", "Traceback"):
        assert secret not in response["body"]


def test_a_bad_configuration_is_a_500(monkeypatch):
    def broken():
        raise ConfigError("DB_HOST is required")

    monkeypatch.setattr(handler, "_build_app", broken)

    response, body = call()

    assert response["statusCode"] == 500
    assert body == {
        "status": "error",
        "timestamp": body["timestamp"],
        "request_id": "req-123",
        "error": "configuration",
    }


def test_an_unexpected_exception_is_a_generic_500(monkeypatch):
    install(monkeypatch, RuntimeError("boom with internal details"))

    response, body = call()

    assert response["statusCode"] == 500
    assert body["error"] == "internal"
    assert "boom" not in response["body"]
