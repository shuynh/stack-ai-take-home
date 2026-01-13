locals {
  # Map workspace names to environment
  env_map = {
    "default" = "dev"
    "prod"    = "prod"
  }

  # Use the workspace name if it exists in map, otherwise fall back to workspace name itself
  env = lookup(local.env_map, terraform.workspace, terraform.workspace)

  # Application name
  application_name = "supabase"

  # AWS Region per environment
  aws_region = {
    "dev"  = "us-east-2"
    "prod" = "us-east-2"
  }

  # VPC CIDR blocks
  vpc_cidr = {
    "dev"  = "10.0.0.0/16"
    "prod" = "10.1.0.0/16"
  }

  # Public subnet CIDRs (for NAT gateways, ALBs)
  public_subnet_cidrs = {
    "dev"  = ["10.0.1.0/24", "10.0.2.0/24"]
    "prod" = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  }

  # Private subnet CIDRs (for EKS nodes, RDS)
  private_subnet_cidrs = {
    "dev"  = ["10.0.10.0/24", "10.0.11.0/24"]
    "prod" = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
  }

  # EKS cluster version
  eks_cluster_version = "1.28"

  # EKS node group configuration
  eks_node_instance_types = {
    "dev"  = ["t3.large"]
    "prod" = ["t3.xlarge"]
  }

  eks_node_desired_size = {
    "dev"  = 2
    "prod" = 4
  }

  eks_node_min_size = {
    "dev"  = 2
    "prod" = 3
  }

  eks_node_max_size = {
    "dev"  = 4
    "prod" = 10
  }

  eks_node_disk_size = {
    "dev"  = 50
    "prod" = 100
  }

  # RDS Configuration
  rds_engine_version = "15.5" # PostgreSQL version

  rds_instance_class = {
    "dev"  = "db.r6g.large"
    "prod" = "db.r6g.xlarge"
  }

  rds_allocated_storage = {
    "dev"  = 100 # GB
    "prod" = 500 # GB
  }

  # Availability zones per region
  availability_zones = {
    "dev"  = ["us-east-2a", "us-east-2b"]
    "prod" = ["us-east-2a", "us-east-2b", "us-east-2c"]
  }

  # ACM Certificate ARNs for ALB HTTPS
  # ⚠️ REQUIRED: Update with actual wildcard certificate ARN (*.stack-ai.com)
  # Both environments use the same wildcard cert
  acm_certificate_arn = {
    "dev"  = "arn:aws:acm:us-east-2:ACCOUNT_ID:certificate/WILDCARD_CERT_ID"
    "prod" = "arn:aws:acm:us-east-2:ACCOUNT_ID:certificate/WILDCARD_CERT_ID"
  }
}
