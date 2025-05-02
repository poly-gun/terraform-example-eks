resource "aws_security_group" "rds" {
  name_prefix = "RDS-PostgreSQL-SG-"

  vpc_id = data.aws_vpc.vpc.id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge({
    Name     = "RDS-PostgreSQL-SG"
    Instance = var.database-identifier
  }, {})
}

resource "aws_security_group_rule" "ingress-public" {
  security_group_id = aws_security_group.rds.id

  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]

  to_port   = 5432
  from_port = 5432

  protocol = "tcp"

  type = "ingress"
}

resource "aws_security_group_rule" "ingress-vpc" {
  security_group_id = aws_security_group.rds.id

  to_port   = 5432
  from_port = 5432

  cidr_blocks      = [data.aws_vpc.vpc.cidr_block]

  ipv6_cidr_blocks = data.aws_vpc.vpc.ipv6_cidr_block != "" ? [data.aws_vpc.vpc.ipv6_cidr_block] : null

  protocol = "tcp"

  type = "ingress"
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.rds.id

  to_port   = 5432
  from_port = 5432

  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]

  protocol = "tcp"

  type = "egress"
}

resource "aws_db_instance" "instance" {
  allocated_storage                     = 50
  allow_major_version_upgrade           = true
  apply_immediately                     = true
  auto_minor_version_upgrade            = true
  availability_zone                     = "us-east-2a"
  backup_retention_period               = 1
  backup_target                         = "region"
  backup_window                         = "09:35-10:05"
  ca_cert_identifier                    = "rds-ca-ecc384-g1"
  character_set_name                    = null
  copy_tags_to_snapshot                 = true
  custom_iam_instance_profile           = null
  customer_owned_ip_enabled             = false
  db_name                               = var.database-name
  db_subnet_group_name                  = var.database-subnet-group-name
  dedicated_log_volume                  = false
  delete_automated_backups              = true
  deletion_protection                   = var.database-deletion-protection
  enabled_cloudwatch_logs_exports       = []
  engine                                = "postgres"
  engine_version                        = "16.3"
  final_snapshot_identifier             = null
  iam_database_authentication_enabled   = true
  identifier                            = var.database-identifier
  identifier_prefix                     = null
  instance_class                        = var.database-instance-class
  kms_key_id                            = null
  license_model                         = "postgresql-license"
  maintenance_window                    = "thu:05:12-thu:05:42"
  max_allocated_storage                 = 1000
  monitoring_interval                   = 0
  monitoring_role_arn                   = null
  multi_az                              = false
  nchar_character_set_name              = null
  network_type                          = "IPV4"
  // network_type                          = "DUAL"
  option_group_name                     = "default:postgres-16"
  parameter_group_name                  = "default.postgres16"
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = null
  performance_insights_retention_period = 7
  port                                  = 5432
  publicly_accessible                   = true
  replica_mode                          = null
  replicate_source_db                   = null
  skip_final_snapshot                   = true
  snapshot_identifier                   = null
  storage_encrypted                     = false
  storage_type                          = "gp3"
  tags = {}
  tags_all = {}
  timezone                              = null
  username                              = var.database-username
  password                              = random_password.password.result
  vpc_security_group_ids                = [aws_security_group.rds.id]

  lifecycle {
    ignore_changes = [
      engine_version
    ]
  }
}

resource "random_password" "password" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "credentials" {
  name                    = lower(format("%s/%s/rds/postgres/%s/configuration", var.namespace, var.environment, var.database-identifier))
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "credentials" {
  secret_id     = aws_secretsmanager_secret.credentials.id
  secret_string = jsonencode({
    username             = var.database-username
    password             = random_password.password.result
    engine               = "postgres"
    host                 = aws_db_instance.instance.endpoint
    port                 = aws_db_instance.instance.port
    dbInstanceIdentifier = aws_db_instance.instance.identifier

    // dbClusterIdentifier = aws_db_instance.instance.identifier
  })
}
