provider "aws" {
  region = var.region
}

locals {
  fe_domain_name  = join(".", [var.fe_subdomain, var.domain_name])
  api_domain_name = join(".", [var.api_subdomain, var.domain_name])
}

### ACM
module "acm" {
  source = "terraform-aws-modules/acm/aws"

  domain_name = local.fe_domain_name
  zone_id     = data.cloudflare_zone.this.id

  subject_alternative_names = [
    local.api_domain_name
  ]

  create_route53_records  = false
  validation_record_fqdns = cloudflare_record.validation.*.hostname
}

resource "cloudflare_record" "validation" {
  count = length(module.acm.distinct_domain_names)

  zone_id = data.cloudflare_zone.this.id
  name    = element(module.acm.validation_domains, count.index)["resource_record_name"]
  type    = element(module.acm.validation_domains, count.index)["resource_record_type"]
  value   = replace(element(module.acm.validation_domains, count.index)["resource_record_value"], "/.$/", "")
  ttl     = 60
  proxied = false

  allow_overwrite = true
}

data "cloudflare_zone" "this" {
  name = var.domain_name
}

### Frontend S3 Bucket
module "frontend" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket        = local.fe_domain_name
  acl           = "private"
  attach_policy = true
  policy        = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${local.fe_domain_name}/*",
            "Condition": {
                "IpAddress": {
                    "aws:SourceIp": [
                        "2400:cb00::/32",
                        "2606:4700::/32",
                        "2803:f800::/32",
                        "2405:b500::/32",
                        "2405:8100::/32",
                        "2a06:98c0::/29",
                        "2c0f:f248::/32",
                        "173.245.48.0/20",
                        "103.21.244.0/22",
                        "103.22.200.0/22",
                        "103.31.4.0/22",
                        "141.101.64.0/18",
                        "108.162.192.0/18",
                        "190.93.240.0/20",
                        "188.114.96.0/20",
                        "197.234.240.0/22",
                        "198.41.128.0/17",
                        "162.158.0.0/15",
                        "172.64.0.0/13",
                        "131.0.72.0/22",
                        "104.16.0.0/13",
                        "104.24.0.0/14"
                    ]
                }
            }
        }
    ]
}
POLICY

  website = {
    index_document = "index.html"
    error_document = "index.html"
  }
}

resource "cloudflare_record" "frontend" {
  zone_id = data.cloudflare_zone.this.id
  name    = var.fe_subdomain
  type    = "CNAME"
  value   = module.frontend.s3_bucket_website_endpoint
  ttl     = 1
  proxied = true

  allow_overwrite = true
}

### Backend S3
resource "aws_s3_bucket" "ugt_lambda_states" {
  bucket = join("-", [var.env_name, var.region, "lambda-states"])

  force_destroy = true
}

### API
resource "aws_lambda_function" "send_sms" {
  function_name = "SendSms"

  s3_bucket = aws_s3_bucket.ugt_lambda_states.id
  s3_key    = "send-sms.zip"

  timeout = 10
  handler = "send-sms.handler"
  runtime = "nodejs14.x"
  tracing_config { mode = "Active" }

  role = aws_iam_role.send_sms_lambda_role.arn
}

resource "aws_cloudwatch_log_group" "send_sms_log_group" {
  name = "/aws/lambda/${aws_lambda_function.send_sms.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "send_sms_lambda_role" {
  name               = "send_sms_lambda_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "read_incident_lambda_policy_attachment" {
  role       = aws_iam_role.send_sms_lambda_role.id
  policy_arn = aws_iam_policy.send_sms_policy.arn
}

resource "aws_iam_role_policy_attachment" "aws_lambda_basic_execution_role_attachment" {
  role       = aws_iam_role.send_sms_lambda_role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "aws_xray_write_only_access_attachment" {
  role       = aws_iam_role.send_sms_lambda_role.id
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_iam_policy" "send_sms_policy" {
  name        = "send_sms_policy"
  description = "send_sms_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sns:Publish",
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_lambda_function_url" "send_sms_url" {
  function_name      = aws_lambda_function.send_sms.function_name
  authorization_type = "NONE"
  cors {
    allow_credentials = false
    allow_origins     = var.is_production_env ? ["https://${local.fe_domain_name}"] : ["*"]
    allow_methods     = ["POST"]
    allow_headers     = ["Content-Type", "Content-Length", "Accept-Encoding", "Connection", "User-Agent"]
    expose_headers    = ["Content-Type", "Content-Length", "Content-Encoding", "Connection", "Date"]
    max_age           = 300
  }
}

resource "cloudflare_record" "backend" {
  zone_id = data.cloudflare_zone.this.id
  name    = var.api_subdomain
  type    = "CNAME"
  value   = aws_lambda_function_url.send_sms_url.function_url
  ttl     = 1
  proxied = true

  allow_overwrite = true
}