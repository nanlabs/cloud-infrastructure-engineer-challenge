locals {
  identifier = "${var.name}-db"
  log_types  = ["postgresql", "upgrade"]
}

resource "aws_db_subnet_group" "this" {
  name        = local.identifier
  description = "Isolated subnets for ${local.identifier}"
  subnet_ids  = var.subnet_ids
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${local.identifier}-"
  family      = "postgres${var.postgres_major_version}"
  description = "Parameters for ${local.identifier}"

  # RDS reports this parameter as pending-reboot; declaring "immediate" shows a diff on every plan.
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = "500"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_statement"
    value        = "ddl"
    apply_method = "immediate"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# RDS creates these groups on its own with no expiry and no encryption, so
# create them first and the instance writes into them.
resource "aws_cloudwatch_log_group" "this" {
  # checkov:skip=CKV_AWS_338: retention is a variable; a year of database logs is not worth the cost here
  for_each = toset(local.log_types)

  name              = "/aws/rds/instance/${local.identifier}/${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn
}

data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "${local.identifier}-enhanced-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "random_id" "final_snapshot" {
  byte_length = 4
}

resource "aws_db_instance" "this" {
  # checkov:skip=CKV_AWS_157: multi_az is a per-environment setting, on in the prod profile
  # checkov:skip=CKV_AWS_353: Performance Insights is not enabled; CloudWatch and enhanced monitoring cover this workload
  # checkov:skip=CKV_AWS_354: Performance Insights is not enabled
  identifier = local.identifier

  engine         = "postgres"
  engine_version = var.postgres_major_version
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.master_username
  port     = var.port

  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  storage_type          = "gp3"
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.this.name
  ca_cert_identifier     = "rds-ca-rsa2048-g1"

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.identifier}-final-${random_id.final_snapshot.hex}"
  apply_immediately         = var.apply_immediately

  auto_minor_version_upgrade          = true
  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = local.log_types
  monitoring_interval                 = 60
  monitoring_role_arn                 = aws_iam_role.monitoring.arn

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy_attachment.monitoring,
  ]
}
