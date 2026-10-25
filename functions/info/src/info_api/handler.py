from __future__ import annotations

import logging
import os
from typing import Any

from info_api import responses
from info_api.config import ConfigError, Settings
from info_api.credentials import CredentialsProvider
from info_api.database import Database, DatabaseError
from info_api.metadata import InstanceMetadata

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


class App:
    def __init__(self, database: Database, metadata: InstanceMetadata, region: str | None) -> None:
        self._database = database
        self._metadata = metadata
        self._region = region

    def handle(self, request_id: str, cold_start: bool) -> dict[str, Any]:
        try:
            status = self._database.probe()
        except DatabaseError as exc:
            logger.warning(
                "database unavailable",
                extra={"request_id": request_id, "category": exc.category},
            )
            return responses.degraded(
                request_id=request_id, category=exc.category, cold_start=cold_start
            )

        logger.info(
            "database ok",
            extra={"request_id": request_id, "latency_ms": status.latency_ms},
        )
        return responses.ok(
            request_id=request_id,
            status=status,
            instance=self._metadata.get(),
            region=self._region,
            cold_start=cold_start,
        )


_app: App | None = None
_cold_start = True


def _build_app() -> App:
    settings = Settings.from_env()
    credentials = CredentialsProvider(settings)
    return App(
        database=Database(settings, credentials),
        metadata=InstanceMetadata(settings),
        region=os.environ.get("AWS_REGION"),
    )


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    global _app, _cold_start
    cold_start, _cold_start = _cold_start, False
    request_id = context.aws_request_id

    try:
        if _app is None:
            _app = _build_app()
        return _app.handle(request_id, cold_start)
    except ConfigError as exc:
        logger.error("invalid configuration", extra={"request_id": request_id, "reason": str(exc)})
        return responses.failure(request_id=request_id, category="configuration")
    except Exception:
        logger.exception("unexpected error", extra={"request_id": request_id})
        return responses.failure(request_id=request_id, category="internal")
