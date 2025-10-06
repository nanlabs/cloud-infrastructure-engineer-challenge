data "archive_file" "zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/lambda.zip"
}


resource "aws_iam_role" "lambda_exec" {
  name = "${var.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_lambda_function" "this" {
  function_name    = var.name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "app.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.zip.output_path)
  memory_size      = var.memory_mb
  timeout          = var.timeout_sec
  environment {
    variables = var.environment
  }

  # En LocalStack no se usan subnets/SG, pero el provider permite enviarlos si existen
  vpc_config {
    subnet_ids         = var.use_localstack ? [] : var.subnet_ids
    security_group_ids = var.use_localstack ? [] : var.security_group_ids
  }
}


