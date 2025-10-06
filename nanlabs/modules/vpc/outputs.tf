output "vpc_id" {
  value = var.use_localstack ? "vpc-simulated" : aws_vpc.this[0].id
}

output "private_subnet_ids" {
  value = var.use_localstack ? ["subnet-sim-1", "subnet-sim-2"] : [

  ]
}

output "lambda_sg_id" {
  value = var.use_localstack ? "sg-sim-lambda" : aws_security_group.lambda[0].id
}

output "db_sg_id" {
  value = var.use_localstack ? "sg-sim-db" : aws_security_group.db[0].id
}
