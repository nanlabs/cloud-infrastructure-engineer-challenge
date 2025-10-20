resource "aws_lambda_layer_version" "psycopg2_layer" {
  layer_name               = "nanlabs-psycopg2-layer"
  filename                 = "./layer/psycopg2_layer.zip"
  compatible_runtimes      = ["python3.13"]
  compatible_architectures = ["x86_64", "arm64"]
}

resource "aws_lambda_function" "lambda" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "nanlabs-lambda-function"
  runtime       = "python3.13"
  role          = aws_iam_role.lambda_rds_role.arn
  handler       = "lambda_function.lambda_handler"
  memory_size   = 128
  timeout       = 60
  architectures = ["x86_64"]

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda-sg.id]
  }

  environment {
    variables = {
      DB_HOST = aws_db_instance.nanlabs-rds.address
      DB_NAME = aws_db_instance.nanlabs-rds.db_name
      DB_USER = postgresql_role.nanlabs_user.name
      REGION_NAME = var.region
    }
  }

  layers = [aws_lambda_layer_version.psycopg2_layer.arn]
}