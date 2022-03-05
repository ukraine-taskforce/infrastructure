module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  name          = var.name
  description   = var.description
  protocol_type = "HTTP"

  cors_configuration = {
    allow_headers = var.allow_headers
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

  domain_name                 = var.domain_name
  domain_name_certificate_arn = var.domain_name_certificate_arn

  # Routes and integrations
  integrations = var.integrations

  tags = {
    Name = var.name
  }
}
