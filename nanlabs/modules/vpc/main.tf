resource "aws_vpc" "this" {
  count      = var.use_localstack ? 0 : 1
  cidr_block = var.cidr_block
  tags       = { Name = var.name }
}

# ... (AWS real) crear subnets, IGW, NAT GW, rutas, etc.

# Security Group Lambda (AWS real)
resource "aws_security_group" "lambda" {
  count       = var.use_localstack ? 0 : 1
  name        = "${var.name}-lambda-sg"
  description = "Lambda SG"
  vpc_id      = aws_vpc.this[0].id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group DB (AWS real)
resource "aws_security_group" "db" {
  count       = var.use_localstack ? 0 : 1
  name        = "${var.name}-db-sg"
  description = "DB SG"
  vpc_id      = aws_vpc.this[0].id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda[0].id]
  }
}
