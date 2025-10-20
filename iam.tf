# alta de rol para la lambda
resource "aws_iam_role" "lambda_rds_role" {
  name               = "nanlabs-lambda-rds-db-access-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "rds-db-connect-policy" {
  name        = "nanlabs-lambda-rds-db-access-policy"
  description = "Allows Lambda to connect to RDS using IAM DB authentication"
  policy      = data.aws_iam_policy_document.lambda_rds_connect_policy.json
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_rds_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda_rds_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "rds_connect_customer" {
  role       = aws_iam_role.lambda_rds_role.name
  policy_arn = aws_iam_policy.rds-db-connect-policy.arn
}