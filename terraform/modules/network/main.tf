data "aws_availability_zones" "available" {
  state = "available"

  # Skip Local Zones / Wavelength zones: only regular AZs
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # The VPC CIDR is split in /24 blocks (for a /16): public 0-9, private 10-19, database 20-29
  public_subnet_cidrs   = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 10 + i)]
  database_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 20 + i)]

  nat_gateway_count = var.single_nat_gateway ? 1 : var.az_count
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.name
  }
}

# Strip all rules from the default security group so nothing can rely on it (CIS AWS 5.4)
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-default-do-not-use"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.name
  }
}

################################################################################
# Subnets
################################################################################

# Public tier: only hosts the NAT Gateway(s). Nothing gets a public IP implicitly.
resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

# Private tier: Lambda ENIs. Outbound internet only through the NAT Gateway.
resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.name}-private-${local.azs[count.index]}"
    Tier = "private"
  }
}

# Database tier: isolated, no route to the internet at all.
resource "aws_subnet" "database" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.database_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.name}-database-${local.azs[count.index]}"
    Tier = "database"
  }
}

################################################################################
# NAT Gateway(s)
################################################################################

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-${local.azs[count.index]}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.name}-${local.azs[count.index]}"
  }

  depends_on = [aws_internet_gateway.this]
}

################################################################################
# Route tables
################################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One route table per AZ so switching to one NAT per AZ is a variable change, not a refactor
resource "aws_route_table" "private" {
  count = var.az_count

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = {
    Name = "${var.name}-private-${local.azs[count.index]}"
  }
}

resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Only the implicit local route: the database tier cannot reach (or be reached from) the internet
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-database"
  }
}

resource "aws_route_table_association" "database" {
  count = var.az_count

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}
