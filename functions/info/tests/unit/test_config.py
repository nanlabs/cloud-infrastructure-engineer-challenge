import pytest

from info_api.config import ConfigError, Settings


def test_defaults_apply_when_only_required_values_are_set(base_env):
    settings = Settings.from_env(base_env)

    assert settings.db_port == 5432
    assert settings.ssl_mode == "verify-full"
    assert settings.connect_timeout_s == 3.0
    assert settings.statement_timeout_ms == 2000
    assert settings.ca_bundle.is_file()


def test_local_runs_can_use_a_plain_user_and_password():
    env = {"DB_HOST": "localhost", "DB_NAME": "appdb", "DB_USER": "app", "DB_PASSWORD": "pw"}

    settings = Settings.from_env(env)

    assert settings.secret_arn is None
    assert settings.db_user == "app"


def test_password_is_not_shown_in_repr():
    env = {"DB_HOST": "localhost", "DB_NAME": "appdb", "DB_USER": "app", "DB_PASSWORD": "pw-1234"}

    assert "pw-1234" not in repr(Settings.from_env(env))


@pytest.mark.parametrize("missing", ["DB_HOST", "DB_NAME"])
def test_required_values_are_enforced(base_env, missing):
    env = {key: value for key, value in base_env.items() if key != missing}

    with pytest.raises(ConfigError, match=missing):
        Settings.from_env(env)


def test_credentials_source_is_required():
    env = {"DB_HOST": "localhost", "DB_NAME": "appdb"}

    with pytest.raises(ConfigError, match="DB_SECRET_ARN"):
        Settings.from_env(env)


@pytest.mark.parametrize(
    ("key", "value"),
    [
        ("DB_PORT", "abc"),
        ("DB_PORT", "70000"),
        ("DB_CONNECT_TIMEOUT_S", "0"),
        ("DB_STATEMENT_TIMEOUT_MS", "99999999"),
        ("DB_SSL_MODE", "prefer"),
    ],
)
def test_invalid_values_are_rejected(base_env, key, value):
    with pytest.raises(ConfigError, match=key):
        Settings.from_env({**base_env, key: value})
