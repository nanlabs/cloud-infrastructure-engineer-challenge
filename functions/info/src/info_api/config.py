from __future__ import annotations

import os
from collections.abc import Mapping
from dataclasses import dataclass, field
from pathlib import Path

CA_BUNDLE = Path(__file__).parent / "certs" / "global-bundle.pem"
SSL_MODES = ("verify-full", "disable")


class ConfigError(ValueError):
    """The environment does not describe a usable configuration."""


@dataclass(frozen=True)
class Settings:
    db_host: str
    db_port: int
    db_name: str
    db_instance_id: str | None
    secret_arn: str | None
    db_user: str | None
    db_password: str | None = field(repr=False)
    ssl_mode: str
    connect_timeout_s: float
    statement_timeout_ms: int
    ca_bundle: Path = CA_BUNDLE

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> Settings:
        env = os.environ if env is None else env

        host = _required(env, "DB_HOST")
        name = _required(env, "DB_NAME")
        secret_arn = env.get("DB_SECRET_ARN") or None
        user = env.get("DB_USER") or None
        password = env.get("DB_PASSWORD") or None

        if secret_arn is None and (user is None or password is None):
            raise ConfigError("set DB_SECRET_ARN, or DB_USER and DB_PASSWORD for local runs")

        ssl_mode = env.get("DB_SSL_MODE", "verify-full")
        if ssl_mode not in SSL_MODES:
            raise ConfigError(f"DB_SSL_MODE must be one of {', '.join(SSL_MODES)}")

        return cls(
            db_host=host,
            db_port=_int(env, "DB_PORT", default=5432, low=1, high=65535),
            db_name=name,
            db_instance_id=env.get("DB_INSTANCE_ID") or None,
            secret_arn=secret_arn,
            db_user=user,
            db_password=password,
            ssl_mode=ssl_mode,
            connect_timeout_s=float(_int(env, "DB_CONNECT_TIMEOUT_S", default=3, low=1, high=10)),
            statement_timeout_ms=_int(
                env, "DB_STATEMENT_TIMEOUT_MS", default=2000, low=100, high=10000
            ),
        )


def _required(env: Mapping[str, str], key: str) -> str:
    value = env.get(key)
    if not value:
        raise ConfigError(f"{key} is required")
    return value


def _int(env: Mapping[str, str], key: str, *, default: int, low: int, high: int) -> int:
    raw = env.get(key)
    if raw is None or raw == "":
        return default
    try:
        value = int(raw)
    except ValueError as exc:
        raise ConfigError(f"{key} must be an integer") from exc
    if not low <= value <= high:
        raise ConfigError(f"{key} must be between {low} and {high}")
    return value
