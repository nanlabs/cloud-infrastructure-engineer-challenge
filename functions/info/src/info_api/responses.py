from __future__ import annotations

import json
from dataclasses import asdict
from datetime import UTC, datetime
from typing import Any

from info_api.database import DbStatus

HEADERS = {"content-type": "application/json", "cache-control": "no-store"}


def json_response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    return {"statusCode": status_code, "headers": HEADERS, "body": json.dumps(body)}


def ok(
    *,
    request_id: str,
    status: DbStatus,
    instance: dict[str, Any] | None,
    region: str | None,
    cold_start: bool,
) -> dict[str, Any]:
    return json_response(
        200,
        {
            "status": "ok",
            "timestamp": _now(),
            "request_id": request_id,
            "database": {"connected": True, "engine": "postgres", **asdict(status)},
            "instance": instance,
            "runtime": {"region": region, "cold_start": cold_start},
        },
    )


def degraded(*, request_id: str, category: str, cold_start: bool) -> dict[str, Any]:
    """The database is unreachable. The category says why, without any detail
    about hosts, users or the underlying exception."""
    return json_response(
        503,
        {
            "status": "degraded",
            "timestamp": _now(),
            "request_id": request_id,
            "database": {"connected": False, "error": category},
            "runtime": {"cold_start": cold_start},
        },
    )


def failure(*, request_id: str, category: str) -> dict[str, Any]:
    return json_response(
        500,
        {
            "status": "error",
            "timestamp": _now(),
            "request_id": request_id,
            "error": category,
        },
    )


def _now() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
