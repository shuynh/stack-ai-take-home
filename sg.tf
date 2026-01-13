# Security Group for RDS PostgreSQL
resource "aws_security_group" "rds" {
  name_prefix = "${local.env}-${local.application_name}-rds-"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${local.env}-${local.application_name}-rds-sg"
    environment = local.env
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Allow PostgreSQL access from EKS nodes
resource "aws_security_group_rule" "rds_ingress_from_eks" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  security_group_id        = aws_security_group.rds.id
  description              = "Allow PostgreSQL access from EKS cluster"
}

# Allow all outbound traffic from RDS
resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
}

# Security Group for EKS additional node rules (optional, EKS creates its own)
resource "aws_security_group" "eks_additional" {
  name_prefix = "${local.env}-${local.application_name}-eks-additional-"
  description = "Additional security group for EKS nodes"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name                                                               = "${local.env}-${local.application_name}-eks-additional-sg"
    environment                                                        = local.env
    "kubernetes.io/cluster/${local.env}-${local.application_name}-eks" = "owned"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Allow nodes to communicate with each other
resource "aws_security_group_rule" "eks_additional_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.eks_additional.id
  description       = "Allow nodes to communicate with each other"
}

# Allow all outbound traffic from EKS nodes
resource "aws_security_group_rule" "eks_additional_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_additional.id
  description       = "Allow all outbound traffic"
}

# Allow HTTPS from anywhere (for ingress controller)
resource "aws_security_group_rule" "eks_additional_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_additional.id
  description       = "Allow HTTPS from anywhere"
}

# Allow HTTP from anywhere (for ingress controller)
resource "aws_security_group_rule" "eks_additional_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_additional.id
  description       = "Allow HTTP from anywhere"
}
