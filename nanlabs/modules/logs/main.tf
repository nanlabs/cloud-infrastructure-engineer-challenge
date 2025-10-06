variable "name_prefix" { type = string }

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name_prefix}"
  retention_in_days = 7
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}
