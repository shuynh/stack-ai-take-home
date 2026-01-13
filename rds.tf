# DB Subnet Group for RDS
resource "aws_db_subnet_group" "postgres" {
  name       = "${local.env}-${local.application_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${local.env}-${local.application_name}-db-subnet-group"
    environment = local.env
  }
}

# PostgreSQL RDS Instance (Multi-AZ)
resource "aws_db_instance" "postgres" {
  identifier     = "${local.env}-${local.application_name}-postgres"
  engine         = "postgres"
  engine_version = local.rds_engine_version
  instance_class = local.rds_instance_class[local.env]

  # Storage
  allocated_storage     = local.rds_allocated_storage[local.env]
  max_allocated_storage = local.rds_allocated_storage[local.env] * 2 # Auto-scaling up to 2x
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database
  db_name  = "supabase"
  username = "supabase_admin"
  password = random_password.db_master_password.result
  port     = 5432

  # Network
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = true

  # Backup
  backup_retention_period   = 30
  backup_window             = "03:00-04:00"
  maintenance_window        = "mon:04:00-mon:05:00"
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.env}-${local.application_name}-postgres-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  copy_tags_to_snapshot     = true

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = true
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  # Protection
  deletion_protection = true

  # Parameter Group
  parameter_group_name = aws_db_parameter_group.postgres.name

  tags = {
    Name        = "${local.env}-${local.application_name}-postgres"
    environment = local.env
  }

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

# Read Replica for Production (Read Scaling)
resource "aws_db_instance" "postgres_read_replica" {
  count              = local.env == "prod" ? 1 : 0
  identifier         = "${local.env}-${local.application_name}-postgres-read-replica"
  replicate_source_db = aws_db_instance.postgres.identifier
  instance_class     = local.rds_instance_class[local.env]

  # Storage - inherited from primary
  storage_encrypted = true

  # Network
  publicly_accessible = false
  multi_az            = false # Read replicas can't be multi-AZ

  # Monitoring
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  # Replicas don't have backup settings (use primary)
  skip_final_snapshot = true

  tags = {
    Name        = "${local.env}-${local.application_name}-postgres-read-replica"
    environment = local.env
  }
}

# RDS Parameter Group
resource "aws_db_parameter_group" "postgres" {
  name        = "${local.env}-${local.application_name}-postgres-pg"
  family      = "postgres15"
  description = "Parameter group for ${local.env} Supabase PostgreSQL"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pgaudit"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = {
    Name        = "${local.env}-${local.application_name}-postgres-pg"
    environment = local.env
  }
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.env}-${local.application_name}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${local.env}-${local.application_name}-rds-monitoring"
    environment = local.env
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Alarms for RDS
resource "aws_sns_topic" "rds_alarms" {
  name = "${local.env}-${local.application_name}-rds-alarms"

  tags = {
    Name        = "${local.env}-${local.application_name}-rds-alarms"
    environment = local.env
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.env}-${local.application_name}-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization exceeds 80%"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  alarm_actions = [aws_sns_topic.rds_alarms.arn]

  tags = {
    Name        = "${local.env}-${local.application_name}-rds-cpu"
    environment = local.env
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_memory" {
  alarm_name          = "${local.env}-${local.application_name}-rds-free-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 1000000000 # 1GB in bytes
  alarm_description   = "RDS freeable memory is less than 1GB"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  alarm_actions = [aws_sns_topic.rds_alarms.arn]

  tags = {
    Name        = "${local.env}-${local.application_name}-rds-free-memory"
    environment = local.env
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${local.env}-${local.application_name}-rds-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "RDS database connections exceed 100"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  alarm_actions = [aws_sns_topic.rds_alarms.arn]

  tags = {
    Name        = "${local.env}-${local.application_name}-rds-connections"
    environment = local.env
  }
}
