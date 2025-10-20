resource "aws_vpc" "nanlabs-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "nanlabs-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.nanlabs-vpc.id
  tags = {
    Name = "nanlabs-igw"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.nanlabs-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  # no asigna ip publica porque es privada
  map_public_ip_on_launch = false

  tags = {
    Name = "nanlabs-private-subnet"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.nanlabs-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  # asigna ip publica porque... es pública
  map_public_ip_on_launch = true

  tags = {
    Name = "nanlabs-public-subnet"
  }
}

# tengo que crear una eip para el nat porque vive en la subnet pública 
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nanlabs-nat-eip"
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
  # necesito el igw primero para tener mi subnet pública
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "nanlabs-nat-gateway"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.nanlabs-vpc.id

  route {
    # ruta 0.0.0.0/0 para el igw
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "nanlabs-vpc-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.nanlabs-vpc.id

  route {
    # ruta 0/0 para el nat 
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "nanlabs-vpc-private-rt"
  }
}

## enruta trafica a traves del igw
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

## enruta el trafico hacia el nat que tiene salida a ig
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

#alta de sgs + reglas 
resource "aws_security_group" "lambda-sg" {
  name        = "nanlabs-lambda-sg"
  description = "SG that allows connection from Lambda to the rest of the VPC"
  vpc_id      = aws_vpc.nanlabs-vpc.id
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_vpc" {
  security_group_id = aws_security_group.lambda-sg.id
  cidr_ipv4         = "10.0.0.0/16"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  description = "Allow outbound traffic from the Lambda function to the rest of the VPC"
}

resource "aws_security_group" "rds-sg" {
  name        = "nanlabs-rds-sg"
  description = "SG that allows connection from Lambda to RDS"
  vpc_id      = aws_vpc.nanlabs-vpc.id
  depends_on  = [aws_security_group.lambda-sg]
}

resource "aws_vpc_security_group_ingress_rule" "allow_inbound_lambda" {
  security_group_id            = aws_security_group.rds-sg.id
  referenced_security_group_id = aws_security_group.lambda-sg.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description = "Allow inbound traffic from the Lambda function to the RDS"
}

# creo que necesito esto, sino no puedo automatizar el alta del role en la db de la rds
# idealmente se ejecutaria desde una ec2 dentro de la misma vpc y no tendria que usar mi ip publica
resource "aws_vpc_security_group_ingress_rule" "allow_inbound_pc" {
  security_group_id = aws_security_group.rds-sg.id
  cidr_ipv4         = var.my-public-ip
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
}