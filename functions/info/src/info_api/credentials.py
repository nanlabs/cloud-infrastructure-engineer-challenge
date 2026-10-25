from __future__ import annotations

import json
import logging
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

import boto3
from botocore.config import Config

from info_api.config import Settings

logger = logging.getLogger(__name__)

CACHE_TTL_S = 300


class CredentialsError(Exception):
    """The database credentials could not be read."""


@dataclass(frozen=True)
class Credentials:
    username: str
    password: str = field(repr=False)


class CredentialsProvider:
    """Reads the database credentials, caching the Secrets Manager answer.

    RDS rotates its managed secret, so the cache expires on a timer and can be
    dropped early with invalidate() after an authentication failure.
    """

    def __init__(
        self,
        settings: Settings,
        client: Any | None = None,
        clock: Callable[[], float] = time.monotonic,
        ttl_s: float = CACHE_TTL_S,
    ) -> None:
        self._settings = settings
        self._client = client
        self._clock = clock
        self._ttl_s = ttl_s
        self._cached: Credentials | None = None
        self._fetched_at = 0.0

    def get(self) -> Credentials:
        if self._settings.secret_arn is None:
            return Credentials(
                username=self._settings.db_user or "",
                password=self._settings.db_password or "",
            )

        if self._cached is not None and self._clock() - self._fetched_at < self._ttl_s:
            return self._cached

        self._cached = self._fetch(self._settings.secret_arn)
        self._fetched_at = self._clock()
        return self._cached

    def invalidate(self) -> None:
        self._cached = None

    def _fetch(self, secret_arn: str) -> Credentials:
        try:
            response = self._secrets_client().get_secret_value(SecretId=secret_arn)
            payload = json.loads(response["SecretString"])
            return Credentials(username=payload["username"], password=payload["password"])
        except (KeyError, ValueError, TypeError) as exc:
            raise CredentialsError("secret does not contain a username and password") from exc
        except Exception as exc:
            logger.warning("secret lookup failed", extra={"error_type": type(exc).__name__})
            raise CredentialsError("secret could not be read") from exc

    def _secrets_client(self) -> Any:
        if self._client is None:
            self._client = boto3.client(
                "secretsmanager",
                config=Config(
                    connect_timeout=1,
                    read_timeout=1,
                    retries={"max_attempts": 2, "mode": "standard"},
                ),
            )
        return self._client
