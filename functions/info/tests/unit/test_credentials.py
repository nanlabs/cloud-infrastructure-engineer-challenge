import json

import boto3
import pytest
from botocore.stub import Stubber

from info_api.credentials import CredentialsError, CredentialsProvider


class Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


@pytest.fixture
def secrets():
    client = boto3.client(
        "secretsmanager",
        region_name="us-east-1",
        aws_access_key_id="test",
        aws_secret_access_key="test",
    )
    with Stubber(client) as stubber:
        yield client, stubber


def add_secret(stubber, settings, password="first"):
    stubber.add_response(
        "get_secret_value",
        {"SecretString": json.dumps({"username": "dbadmin", "password": password})},
        {"SecretId": settings.secret_arn},
    )


def test_reads_the_secret_once_and_serves_it_from_cache(make_settings, secrets):
    client, stubber = secrets
    settings = make_settings()
    add_secret(stubber, settings)
    clock = Clock()
    provider = CredentialsProvider(settings, client=client, clock=clock)

    first = provider.get()
    clock.now += 299
    second = provider.get()

    assert (first.username, first.password) == ("dbadmin", "first")
    assert second is first
    stubber.assert_no_pending_responses()


def test_refreshes_after_the_cache_expires(make_settings, secrets):
    client, stubber = secrets
    settings = make_settings()
    add_secret(stubber, settings, password="first")
    add_secret(stubber, settings, password="rotated")
    clock = Clock()
    provider = CredentialsProvider(settings, client=client, clock=clock)

    provider.get()
    clock.now += 301

    assert provider.get().password == "rotated"


def test_invalidate_forces_a_fresh_read(make_settings, secrets):
    client, stubber = secrets
    settings = make_settings()
    add_secret(stubber, settings, password="first")
    add_secret(stubber, settings, password="rotated")
    provider = CredentialsProvider(settings, client=client, clock=Clock())

    provider.get()
    provider.invalidate()

    assert provider.get().password == "rotated"


def test_local_runs_skip_secrets_manager(make_settings):
    settings = make_settings(DB_SECRET_ARN=None, DB_USER="app", DB_PASSWORD="pw")

    credentials = CredentialsProvider(settings, client=object()).get()

    assert (credentials.username, credentials.password) == ("app", "pw")


def test_password_is_not_shown_in_repr(make_settings):
    settings = make_settings(DB_SECRET_ARN=None, DB_USER="app", DB_PASSWORD="pw-1234")

    assert "pw-1234" not in repr(CredentialsProvider(settings).get())


def test_a_secret_without_a_password_is_an_error(make_settings, secrets):
    client, stubber = secrets
    settings = make_settings()
    stubber.add_response(
        "get_secret_value",
        {"SecretString": json.dumps({"username": "dbadmin"})},
        {"SecretId": settings.secret_arn},
    )

    with pytest.raises(CredentialsError, match="username and password"):
        CredentialsProvider(settings, client=client).get()


def test_an_api_failure_is_reported_without_the_cause(make_settings, secrets):
    client, stubber = secrets
    settings = make_settings()
    stubber.add_client_error("get_secret_value", service_error_code="AccessDeniedException")

    with pytest.raises(CredentialsError, match="could not be read"):
        CredentialsProvider(settings, client=client).get()
