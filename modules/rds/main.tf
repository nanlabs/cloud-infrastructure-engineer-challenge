terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "aws_db_subnet_group" "dbsubnet" {
  name        = "${var.project}-subnet-group-db"
  description = "Subnet group for RDS service"
  subnet_ids  = var.subnet_ids
  tags = merge(var.tags, {
    Name = "${var.project}-subnet-group"
  })
}

resource "aws_db_instance" "db_instance" {
  identifier            = "${var.project}-db-rds"
  engine                = var.engine #"postgres"
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  db_name               = var.dbname

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  #maintenance_window     = var.maintenance_window

  skip_final_snapshot         = true
  storage_encrypted           = var.storage_encrypted
  username                    = var.username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.dbsubnet.name
  vpc_security_group_ids = [var.security_group_id]
  copy_tags_to_snapshot  = true
  tags                   = var.tags
}
