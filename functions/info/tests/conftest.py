from __future__ import annotations

import pytest

from info_api.config import Settings

BASE_ENV = {
    "DB_HOST": "db.internal.example",
    "DB_NAME": "appdb",
    "DB_SECRET_ARN": "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds-db-test",
    "DB_INSTANCE_ID": "info-api-dev-db",
}


@pytest.fixture
def base_env():
    return dict(BASE_ENV)


@pytest.fixture
def make_settings():
    def _make(**overrides: str | None) -> Settings:
        env = {**BASE_ENV, **overrides}
        return Settings.from_env({key: value for key, value in env.items() if value is not None})

    return _make
