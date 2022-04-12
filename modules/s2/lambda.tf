### To instantiate after lambda are uploaded to S3 bucket

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
  value   = trimprefix(aws_lambda_function_url.send_sms_url.function_url, "https://")
  ttl     = 1
  proxied = true

  allow_overwrite = true
}