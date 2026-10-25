mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-monitoring"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!db-mock"
        kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
        secret_status = "active"
      }]
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name                  = "info-api-dev"
  subnet_ids            = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
  security_group_id     = "sg-0123456789abcdef0"
  kms_key_arn           = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  log_kms_key_arn       = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222"
  multi_az              = false
  backup_retention_days = 7
  log_retention_days    = 14
}

run "instance_is_private_encrypted_and_protected" {
  command = plan

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false && aws_db_instance.this.storage_encrypted
    error_message = "The database must be private and encrypted at rest."
  }

  assert {
    condition     = aws_db_instance.this.kms_key_id == var.kms_key_arn
    error_message = "Storage must be encrypted with the data key."
  }

  assert {
    condition = (
      aws_db_instance.this.manage_master_user_password &&
      aws_db_instance.this.password == null &&
      aws_db_instance.this.master_user_secret_kms_key_id == var.kms_key_arn
    )
    error_message = "RDS must manage the master password, encrypted with the data key, and no password may be set."
  }

  assert {
    condition = (
      aws_db_instance.this.deletion_protection &&
      aws_db_instance.this.auto_minor_version_upgrade &&
      aws_db_instance.this.iam_database_authentication_enabled &&
      aws_db_instance.this.copy_tags_to_snapshot
    )
    error_message = "Deletion protection, minor upgrades, IAM authentication and tag copying must default on."
  }

  assert {
    condition = (
      aws_db_instance.this.engine == "postgres" &&
      aws_db_instance.this.engine_version == "17" &&
      aws_db_instance.this.storage_type == "gp3" &&
      aws_db_instance.this.ca_cert_identifier == "rds-ca-rsa2048-g1"
    )
    error_message = "Expected PostgreSQL 17 on gp3 storage with the rds-ca-rsa2048-g1 certificate."
  }
}

run "tls_is_enforced_by_the_parameter_group" {
  command = plan

  assert {
    condition     = aws_db_parameter_group.this.family == "postgres17"
    error_message = "The parameter group family must follow the major version."
  }

  assert {
    condition     = { for p in aws_db_parameter_group.this.parameter : p.name => p.value }["rds.force_ssl"] == "1"
    error_message = "Connections without TLS must be rejected."
  }
}

run "tls_setting_matches_what_rds_reports" {
  command = plan

  assert {
    condition     = { for p in aws_db_parameter_group.this.parameter : p.name => p.apply_method }["rds.force_ssl"] == "pending-reboot"
    error_message = "RDS reports rds.force_ssl as pending-reboot; any other method makes every plan show a change."
  }
}

run "logs_go_to_encrypted_groups_that_exist_first" {
  command = plan

  assert {
    condition     = aws_db_instance.this.enabled_cloudwatch_logs_exports == toset(["postgresql", "upgrade"])
    error_message = "The postgresql and upgrade logs must be exported."
  }

  assert {
    condition     = aws_cloudwatch_log_group.this["postgresql"].name == "/aws/rds/instance/info-api-dev-db/postgresql"
    error_message = "The log group name must match the one RDS writes to."
  }

  assert {
    condition = alltrue([
      for group in aws_cloudwatch_log_group.this :
      group.retention_in_days == 14 && group.kms_key_id == var.log_kms_key_arn
    ])
    error_message = "Every database log group needs the configured retention and the log key."
  }
}

run "backups_use_the_configured_retention" {
  command = plan

  assert {
    condition     = aws_db_instance.this.backup_retention_period == 7
    error_message = "Backup retention must follow the input."
  }
}

run "multi_az_follows_the_input" {
  command = plan

  variables {
    multi_az = true
  }

  assert {
    condition     = aws_db_instance.this.multi_az
    error_message = "multi_az = true must produce a Multi-AZ instance."
  }
}

run "final_snapshot_is_taken_by_default" {
  command = apply

  assert {
    condition     = startswith(aws_db_instance.this.final_snapshot_identifier, "info-api-dev-db-final-")
    error_message = "A final snapshot with a unique name must be requested by default."
  }
}

run "final_snapshot_can_be_skipped" {
  command = plan

  variables {
    skip_final_snapshot = true
  }

  assert {
    condition     = aws_db_instance.this.skip_final_snapshot && aws_db_instance.this.final_snapshot_identifier == null
    error_message = "Skipping the snapshot must not leave a snapshot name behind."
  }
}

run "rejects_a_single_subnet" {
  command = plan

  variables {
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaaa"]
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_zero_backup_retention" {
  command = plan

  variables {
    backup_retention_days = 0
  }

  expect_failures = [var.backup_retention_days]
}

run "rejects_a_storage_ceiling_below_the_start" {
  command = plan

  variables {
    allocated_storage     = 50
    max_allocated_storage = 40
  }

  expect_failures = [var.max_allocated_storage]
}

run "rejects_reserved_master_username" {
  command = plan

  variables {
    master_username = "postgres"
  }

  expect_failures = [var.master_username]
}

run "rejects_a_malformed_major_version" {
  command = plan

  variables {
    postgres_major_version = "seventeen"
  }

  expect_failures = [var.postgres_major_version]
}

run "rejects_unsupported_log_retention" {
  command = plan

  variables {
    log_retention_days = 10
  }

  expect_failures = [var.log_retention_days]
}
