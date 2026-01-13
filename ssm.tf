# Generate random values for Supabase secrets
# These are auto-generated once and stored in SSM Parameter Store

# JWT Secret - Master secret for signing all JWT tokens
# Used by all Supabase services to validate authentication tokens
resource "random_password" "jwt_secret" {
  length  = 32
  special = true
}

# Anon Key - Public API key for anonymous/unauthenticated client access
# Exposed to frontend applications, enforces Row Level Security (RLS) policies
resource "random_password" "anon_key" {
  length  = 64
  special = false
}

# Service Role Key - Admin API key that bypasses all RLS policies
# Used for backend operations, migrations, admin scripts
resource "random_password" "service_role_key" {
  length  = 64
  special = false
}

# Dashboard Password - Password for accessing Supabase Studio web UI
resource "random_password" "dashboard_password" {
  length  = 32
  special = true
}

# Database Master Password - Master password for RDS instance
resource "random_password" "db_master_password" {
  length  = 32
  special = true
}

# SSM Parameters for Supabase configuration
resource "aws_ssm_parameter" "postgres_host" {
  name        = "/${local.env}/${local.application_name}/postgres/host"
  description = "PostgreSQL database host"
  type        = "String"
  value       = aws_db_instance.postgres.address

  tags = {
    Name        = "${local.env}-${local.application_name}-postgres-host"
    environment = local.env
  }
}

resource "aws_ssm_parameter" "postgres_port" {
  name        = "/${local.env}/${local.application_name}/postgres/port"
  description = "PostgreSQL database port"
  type        = "String"
  value       = "5432"

  tags = {
    Name        = "${local.env}-${local.application_name}-postgres-port"
    environment = local.env
  }
}

resource "aws_ssm_parameter" "postgres_db" {
  name        = "/${local.env}/${local.application_name}/postgres/database"
  description = "PostgreSQL database name"
  type        = "String"
  value       = aws_db_instance.postgres.db_name

  tags = {
    Name        = "${local.env}-${local.application_name}-postgres-db"
    environment = local.env
  }
}

resource "aws_ssm_parameter" "postgres_user" {
  name        = "/${local.env}/${local.application_name}/postgres/username"
  description = "PostgreSQL master username"
  type        = "String"
  value       = aws_db_instance.postgres.username

  tags = {
    Name        = "${local.env}-${local.application_name}-postgres-user"
    environment = local.env
  }
}

resource "aws_ssm_parameter" "postgres_password" {
  name        = "/${local.env}/${local.application_name}/postgres/password"
  description = "PostgreSQL master password"
  type        = "SecureString"
  value       = random_password.db_master_password.result

  tags = {
    Name        = "${local.env}-${local.application_name}-postgres-password"
    environment = local.env
  }
}

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/${local.env}/${local.application_name}/jwt/secret"
  description = "JWT secret for Supabase"
  type        = "SecureString"
  value       = random_password.jwt_secret.result

  tags = {
    Name        = "${local.env}-${local.application_name}-jwt-secret"
    environment = local.env
  }
}

resource "aws_ssm_parameter" "anon_key" {
  name        = "/${local.env}/${local.application_name}/jwt/anon-key"
  description = "Anonymous key for Supabase"
  type        = "SecureString"
  value       = random_password.anon_key.result

  tags = {
    Name        = "${local.env}-${local.application_name}-anon-key"
    environment = local.env
  }
}

resource "aws_ssm_parameter" "service_role_key" {
  name        = "/${local.env}/${local.application_name}/jwt/service-role-key"
  description = "Service role key for Supabase"
  type        = "SecureString"
  value       = random_password.service_role_key.result

  tags = {
    Name        = "${local.env}-${local.application_name}-service-role-key"
    environment = local.env
  }
}

resource "aws_ssm_parameter" "dashboard_password" {
  name        = "/${local.env}/${local.application_name}/dashboard/password"
  description = "Dashboard password for Supabase Studio"
  type        = "SecureString"
  value       = random_password.dashboard_password.result

  tags = {
    Name        = "${local.env}-${local.application_name}-dashboard-password"
    environment = local.env
  }
}

resource "aws_ssm_parameter" "s3_bucket" {
  name        = "/${local.env}/${local.application_name}/s3/bucket"
  description = "S3 bucket name for Supabase storage"
  type        = "String"
  value       = aws_s3_bucket.supabase_storage.id

  tags = {
    Name        = "${local.env}-${local.application_name}-s3-bucket"
    environment = local.env
  }
}

resource "aws_ssm_parameter" "s3_region" {
  name        = "/${local.env}/${local.application_name}/s3/region"
  description = "S3 bucket region"
  type        = "String"
  value       = local.aws_region[local.env]

  tags = {
    Name        = "${local.env}-${local.application_name}-s3-region"
    environment = local.env
  }
}

# ⚠️ SMTP Configuration - PLACEHOLDER VALUES
# These parameters have placeholder values and must be updated manually after deployment
# The lifecycle ignore_changes prevents Terraform from overwriting your manual updates
# Update these in AWS Systems Manager Parameter Store with your actual SMTP provider details

resource "aws_ssm_parameter" "smtp_host" {
  name        = "/${local.env}/${local.application_name}/smtp/host"
  description = "SMTP host for Supabase (configure manually)"
  type        = "String"
  value       = "smtp.example.com"

  tags = {
    Name        = "${local.env}-${local.application_name}-smtp-host"
    environment = local.env
  }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "smtp_port" {
  name        = "/${local.env}/${local.application_name}/smtp/port"
  description = "SMTP port for Supabase"
  type        = "String"
  value       = "587"

  tags = {
    Name        = "${local.env}-${local.application_name}-smtp-port"
    environment = local.env
  }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "smtp_user" {
  name        = "/${local.env}/${local.application_name}/smtp/user"
  description = "SMTP username (configure manually)"
  type        = "String"
  value       = "changeme"

  tags = {
    Name        = "${local.env}-${local.application_name}-smtp-user"
    environment = local.env
  }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "smtp_password" {
  name        = "/${local.env}/${local.application_name}/smtp/password"
  description = "SMTP password (configure manually)"
  type        = "SecureString"
  value       = "changeme"

  tags = {
    Name        = "${local.env}-${local.application_name}-smtp-password"
    environment = local.env
  }

  lifecycle {
    ignore_changes = [value]
  }
}
