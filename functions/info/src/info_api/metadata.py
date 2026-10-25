from __future__ import annotations

import logging
import time
from collections.abc import Callable
from typing import Any

import boto3
from botocore.config import Config

from info_api.config import Settings

logger = logging.getLogger(__name__)

SUCCESS_TTL_S = 60
FAILURE_TTL_S = 10


class InstanceMetadata:
    """Instance details from the RDS API, which the database cannot report itself.

    Best effort: any failure returns None, so a slow or blocked RDS API never
    turns a working database into a failed request.
    """

    def __init__(
        self,
        settings: Settings,
        client: Any | None = None,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._settings = settings
        self._client = client
        self._clock = clock
        self._value: dict[str, Any] | None = None
        self._expires_at = 0.0

    def get(self) -> dict[str, Any] | None:
        if self._settings.db_instance_id is None:
            return None
        if self._clock() < self._expires_at:
            return self._value

        try:
            response = self._rds_client().describe_db_instances(
                DBInstanceIdentifier=self._settings.db_instance_id
            )
            self._value = _summarize(response["DBInstances"][0])
            self._expires_at = self._clock() + SUCCESS_TTL_S
        except Exception as exc:
            logger.warning("instance lookup failed", extra={"error_type": type(exc).__name__})
            self._value = None
            self._expires_at = self._clock() + FAILURE_TTL_S
        return self._value

    def _rds_client(self) -> Any:
        if self._client is None:
            self._client = boto3.client(
                "rds",
                config=Config(
                    connect_timeout=1,
                    read_timeout=1,
                    retries={"max_attempts": 1, "mode": "standard"},
                ),
            )
        return self._client


def _summarize(instance: dict[str, Any]) -> dict[str, Any]:
    return {
        "class": instance.get("DBInstanceClass"),
        "status": instance.get("DBInstanceStatus"),
        "multi_az": instance.get("MultiAZ"),
        "availability_zone": instance.get("AvailabilityZone"),
        "storage_type": instance.get("StorageType"),
        "allocated_storage_gb": instance.get("AllocatedStorage"),
        "backup_retention_days": instance.get("BackupRetentionPeriod"),
    }
