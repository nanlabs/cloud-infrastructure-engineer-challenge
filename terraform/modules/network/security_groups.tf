# Both security groups live here so the Lambda <-> database rules reference each other
# without creating a dependency cycle between the lambda and database modules.

resource "aws_security_group" "lambda" {
  name        = "${var.name}-lambda"
  description = "Info Lambda: no ingress, egress only to the database and HTTPS"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name}-lambda"
  }
}

resource "aws_security_group" "database" {
  name        = "${var.name}-database"
  description = "PostgreSQL: ingress only from the Lambda security group"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name}-database"
  }
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_database" {
  security_group_id            = aws_security_group.lambda.id
  referenced_security_group_id = aws_security_group.database.id
  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
  description                  = "PostgreSQL to the database"
}

# The Lambda reads its DB credentials from Secrets Manager (public AWS API) through the NAT Gateway
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "lambda_https" {
  security_group_id = aws_security_group.lambda.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to AWS APIs through the NAT Gateway"
}

resource "aws_vpc_security_group_ingress_rule" "database_from_lambda" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.lambda.id
  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
  description                  = "PostgreSQL from the Info Lambda"
}
