resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr[local.env]
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${local.env}-${local.application_name}-vpc"
    environment = local.env
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${local.env}-${local.application_name}-igw"
    environment = local.env
  }
}

resource "aws_subnet" "public" {
  count = length(local.public_subnet_cidrs[local.env])

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[local.env][count.index]
  availability_zone       = local.availability_zones[local.env][count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                                               = "${local.env}-${local.application_name}-public-${count.index + 1}"
    environment                                                        = local.env
    "kubernetes.io/role/elb"                                           = "1"
    "kubernetes.io/cluster/${local.env}-${local.application_name}-eks" = "shared"
  }
}

resource "aws_subnet" "private" {
  count = length(local.private_subnet_cidrs[local.env])

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[local.env][count.index]
  availability_zone = local.availability_zones[local.env][count.index]

  tags = {
    Name                                                               = "${local.env}-${local.application_name}-private-${count.index + 1}"
    environment                                                        = local.env
    "kubernetes.io/role/internal-elb"                                  = "1"
    "kubernetes.io/cluster/${local.env}-${local.application_name}-eks" = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${local.env}-${local.application_name}-public_route_table"
    environment = local.env
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# EIP for NAT Gateways
resource "aws_eip" "nat" {
  count  = length(local.public_subnet_cidrs[local.env])
  domain = "vpc"

  tags = {
    Name        = "${local.env}-${local.application_name}-nat-eip-${count.index + 1}"
    environment = local.env
  }

  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateways (one per public subnet for high availability)
resource "aws_nat_gateway" "main" {
  count = length(local.public_subnet_cidrs[local.env])

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${local.env}-${local.application_name}-nat-${count.index + 1}"
    environment = local.env
  }

  depends_on = [aws_internet_gateway.igw]
}

# Private route tables (one per private subnet for NAT gateway association)
resource "aws_route_table" "private" {
  count = length(local.private_subnet_cidrs[local.env])

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${local.env}-${local.application_name}-private-rt-${count.index + 1}"
    environment = local.env
  }
}

# Private route table associations
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

data "aws_availability_zones" "available" {
  state = "available"
}
