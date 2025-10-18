terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

data "aws_availability_zones" "available" {}

locals {
  azs = length(var.azs) > 0 ? var.azs : slice(data.aws_availability_zones.available.names, 0, var.azs_count)
}


resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.project}-vpc"
  })
}

# PUBLIC SUBNETS

resource "aws_subnet" "public" {
  count = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) > 0 ? element(local.azs, count.index) : null
  availability_zone_id    = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) == 0 ? element(local.azs, count.index) : null
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name = "${var.project}-public-${count.index + 1}"
  })
}

# PRIVATE SUBNETS

resource "aws_subnet" "private" {
  count = length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  vpc_id               = aws_vpc.vpc.id
  cidr_block           = var.private_subnets[count.index]
  availability_zone    = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) > 0 ? element(local.azs, count.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) == 0 ? element(local.azs, count.index) : null
  tags = merge(var.tags, {
    Name = "${var.project}-private-${count.index + 1}"
  })
}

# INTERNET GATEWAY (for Public Subnets)

resource "aws_internet_gateway" "igw" {
  count  = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.project}-igtw"
  })
}

# ELASTIC IP (for each NAT Gateway)

resource "aws_eip" "nat_eip" {
  count = length(local.azs)
  #vpc = true
  tags = merge(var.tags, {
    Name = "${var.project}-eip-${count.index + 1}"
  })

}

# NAT GATEWAY (for Private Subnets outbound access)
# One NAT GATEWAY per AZ to avoid cross AZ bandwith costs
resource "aws_nat_gateway" "natgw" {
  count = length(aws_eip.nat_eip)
  #count =  length(local.azs)

  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.igw]
  tags = merge(var.tags, {
    Name = "${var.project}-natgtw-${count.index + 1}"
  })
}

# PUBLIC ROUTE TABLE
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }

  tags = merge(var.tags, {
    Name = "${var.project}-public-rt"
  })
}

# PRIVATE ROUTE TABLES (one per AZ, per natgateway)
resource "aws_route_table" "private" {
  count = length(aws_nat_gateway.natgw)

  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw[count.index].id

  }
  tags = merge(var.tags, {
    Name = "${var.project}-private-rt-${count.index + 1}"
  })
}

# ROUTE TABLE ASSOCIATIONS
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table_association" "private" {
  count = length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  subnet_id      = aws_subnet.private[count.index].id #asuming the subnets starts with 1a 1b, etc and the natgateway (from the route table) also placed in public subnets in same order 1a 1b, etc
  route_table_id = aws_route_table.private[count.index].id
}


## SG Lambda
resource "aws_security_group" "security_group_lambda" {
  name        = "${var.project}-lambda-sg"
  description = "Sg para lambda"
  vpc_id      = aws_vpc.vpc.id
  tags        = var.tags
}

resource "aws_security_group_rule" "lambda_to_rds" {
  security_group_id        = aws_security_group.security_group_lambda.id
  type                     = "egress"
  description              = "Allow PostgreSQL traffic to RDS"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.security_group_rds.id
}

resource "aws_security_group_rule" "lambda_to_internet" {
  security_group_id = aws_security_group.security_group_lambda.id
  type              = "egress"
  description       = "Allow HTTPS egress for AWS service access"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

## SG RDS

resource "aws_security_group" "security_group_rds" {
  name        = "${var.project}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.vpc.id

  tags = var.tags
}

resource "aws_security_group_rule" "lambda_access" {
  description              = "Allow Lambda SG to access RDS SG on port 5432"
  security_group_id        = aws_security_group.security_group_rds.id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.security_group_lambda.id
}
