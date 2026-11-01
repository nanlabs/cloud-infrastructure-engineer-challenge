locals {
  engine_major_version = split(".", var.engine_version)[0]
}

resource "aws_db_subnet_group" "this" {
  name        = var.name
  description = "Isolated database subnets for ${var.name}"
  subnet_ids  = var.subnet_ids

  tags = {
    Name = var.name
  }
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-"
  family      = "postgres${local.engine_major_version}"
  description = "PostgreSQL ${local.engine_major_version} parameters for ${var.name}"

  # Reject any non-TLS connection (encryption in transit)
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Log statements slower than 1s to CloudWatch
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Created up front so the exported logs get a retention policy instead of "never expire"
resource "aws_cloudwatch_log_group" "postgresql" {
  name              = "/aws/rds/instance/${var.name}/postgresql"
  retention_in_days = var.log_retention_days
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.master_username
  port     = var.port

  # RDS generates the password, stores it in Secrets Manager and rotates it:
  # the credential never appears in code, variables or Terraform state.
  manage_master_user_password = true

  storage_type          = "gp3"
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage # storage autoscaling
  storage_encrypted     = true

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.this.name

  # Backup & disaster recovery: daily snapshots + point-in-time recovery within the retention window
  backup_retention_period   = var.backup_retention_days
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:30-sun:05:30"
  copy_tags_to_snapshot     = true
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final"
  deletion_protection       = var.deletion_protection

  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name = var.name
  }

  depends_on = [aws_cloudwatch_log_group.postgresql]
}
