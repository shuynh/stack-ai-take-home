output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.address
}

output "rds_read_replica_endpoint" {
  description = "RDS read replica endpoint (prod only)"
  value       = local.env == "prod" ? aws_db_instance.postgres_read_replica[0].address : null
}

output "rds_database_name" {
  description = "Name of the database"
  value       = aws_db_instance.postgres.db_name
}

output "s3_bucket_name" {
  description = "Name of S3 bucket for Supabase storage"
  value       = aws_s3_bucket.supabase_storage.id
}

output "s3_bucket_arn" {
  description = "ARN of S3 bucket for Supabase storage"
  value       = aws_s3_bucket.supabase_storage.arn
}

output "ssm_parameter_prefix" {
  description = "SSM Parameter Store prefix for Supabase secrets"
  value       = "/${local.env}/${local.application_name}/"
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${local.aws_region[local.env]} --name ${aws_eks_cluster.main.name}"
}

output "environment" {
  description = "Current environment"
  value       = local.env
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN for the current environment"
  value       = local.acm_certificate_arn[local.env]
}
