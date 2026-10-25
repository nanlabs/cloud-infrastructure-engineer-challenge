import boto3
import pytest
from botocore.stub import Stubber

from info_api.metadata import FAILURE_TTL_S, SUCCESS_TTL_S, InstanceMetadata

INSTANCE = {
    "DBInstanceIdentifier": "info-api-dev-db",
    "DBInstanceClass": "db.t4g.micro",
    "DBInstanceStatus": "available",
    "MultiAZ": False,
    "AvailabilityZone": "us-east-1a",
    "StorageType": "gp3",
    "AllocatedStorage": 20,
    "BackupRetentionPeriod": 7,
    "MasterUsername": "must-not-leak",
}


class Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


@pytest.fixture
def rds():
    client = boto3.client(
        "rds", region_name="us-east-1", aws_access_key_id="test", aws_secret_access_key="test"
    )
    with Stubber(client) as stubber:
        yield client, stubber


def test_summarises_only_the_fields_meant_for_callers(make_settings, rds):
    client, stubber = rds
    stubber.add_response(
        "describe_db_instances",
        {"DBInstances": [INSTANCE]},
        {"DBInstanceIdentifier": "info-api-dev-db"},
    )

    summary = InstanceMetadata(make_settings(), client=client).get()

    assert summary == {
        "class": "db.t4g.micro",
        "status": "available",
        "multi_az": False,
        "availability_zone": "us-east-1a",
        "storage_type": "gp3",
        "allocated_storage_gb": 20,
        "backup_retention_days": 7,
    }


def test_caches_the_answer(make_settings, rds):
    client, stubber = rds
    stubber.add_response("describe_db_instances", {"DBInstances": [INSTANCE]})
    clock = Clock()
    metadata = InstanceMetadata(make_settings(), client=client, clock=clock)

    first = metadata.get()
    clock.now += SUCCESS_TTL_S - 1

    assert metadata.get() == first
    stubber.assert_no_pending_responses()


def test_failure_returns_none_and_is_remembered_briefly(make_settings, rds):
    client, stubber = rds
    stubber.add_client_error("describe_db_instances", service_error_code="AccessDenied")
    stubber.add_response("describe_db_instances", {"DBInstances": [INSTANCE]})
    clock = Clock()
    metadata = InstanceMetadata(make_settings(), client=client, clock=clock)

    assert metadata.get() is None
    assert metadata.get() is None
    clock.now += FAILURE_TTL_S + 1

    assert metadata.get() is not None


def test_without_an_instance_id_nothing_is_called(make_settings):
    metadata = InstanceMetadata(make_settings(DB_INSTANCE_ID=None), client=object())

    assert metadata.get() is None
