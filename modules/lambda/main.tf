module "lambda" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = var.name
  description   = var.description
  handler       = var.handler
  runtime       = var.runtime

  source_path = var.source

  tags = {
    Name = var.name
  }
}
