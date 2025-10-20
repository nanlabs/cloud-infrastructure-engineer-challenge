# modificar a aurora-serverless y multi az deployment
resource "aws_db_instance" "nanlabs-rds" {
  allocated_storage = 10
  apply_immediately = true
  identifier        = "nanlabs-rds"
  db_name           = "postgres"
  engine            = "postgres"
  engine_version    = "17.4"
  instance_class    = "db.t4g.micro"
  username          = "postgres"
  # az pública para hacerla publicly accesible y correr el script del postgresql provider
  # algo que podría hacer para evitar esto es tener una ec2 en la misma vpc que la rds y levantar todo desde ahí
  availability_zone          = aws_subnet.public.availability_zone
  password                   = random_string.rds-password.result
  skip_final_snapshot        = true
  auto_minor_version_upgrade = true
  # automated backups
  backup_retention_period             = 7
  backup_window                       = "22:00-02:00"
  storage_encrypted                   = true
  kms_key_id                          = data.aws_kms_alias.rds_default_key.target_key_arn
  iam_database_authentication_enabled = true
  vpc_security_group_ids              = [aws_security_group.rds-sg.id]
  database_insights_mode              = "standard"
  performance_insights_enabled        = false
  db_subnet_group_name                = aws_db_subnet_group.nanlabs-rds-subnet-group.name
  publicly_accessible                 = true
}

resource "aws_db_subnet_group" "nanlabs-rds-subnet-group" {
  name        = "nanlabs-rds-subnet-group"
  subnet_ids  = [aws_subnet.private.id, aws_subnet.public.id]
  description = "RDS subnet group for my NaNLABS VPC"
}

resource "random_string" "rds-password" {
  length  = 16
  upper   = true
  special = false
}

output "rds-random-password" {
  value = random_string.rds-password.result
}