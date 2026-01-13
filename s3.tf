# S3 Bucket for Supabase Storage
resource "aws_s3_bucket" "supabase_storage" {
  bucket = "${local.env}-${local.application_name}-storage-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${local.env}-${local.application_name}-storage"
    environment = local.env
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "supabase_storage" {
  bucket = aws_s3_bucket.supabase_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "supabase_storage" {
  bucket = aws_s3_bucket.supabase_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "supabase_storage" {
  bucket = aws_s3_bucket.supabase_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "supabase_storage" {
  bucket = aws_s3_bucket.supabase_storage.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
  }
}

# CORS configuration for Supabase
resource "aws_s3_bucket_cors_configuration" "supabase_storage" {
  bucket = aws_s3_bucket.supabase_storage.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"] # Update this with specific domains in production
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# IAM Role for EKS pods to access S3
resource "aws_iam_role" "supabase_storage" {
  name = "${local.env}-${local.application_name}-storage-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:supabase:supabase-storage"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${local.env}-${local.application_name}-storage-role"
    environment = local.env
  }
}

# IAM Policy for S3 access
resource "aws_iam_role_policy" "supabase_storage" {
  name = "${local.env}-${local.application_name}-storage-policy"
  role = aws_iam_role.supabase_storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.supabase_storage.arn,
          "${aws_s3_bucket.supabase_storage.arn}/*"
        ]
      }
    ]
  })
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
