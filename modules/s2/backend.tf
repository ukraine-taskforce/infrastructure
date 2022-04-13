### To instantiate after lambda are uploaded to S3 bucket
### Backend API Gateway
resource "aws_apigatewayv2_api" "ugt_gw" {
  name          = join("-", [var.env_name, var.region, "api-gateway"])
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = var.is_production_env ? ["https://${local.fe_domain_name}"] : ["*"]
    allow_methods = ["POST", "GET"]
    allow_headers = ["Authorization", "Content-Type"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_stage" "ugt_gw_stage" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  name        = "live"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.ugt_api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_cloudwatch_log_group" "ugt_api_gw" {
  name = "/aws/ugt_api_gw/${aws_apigatewayv2_api.ugt_gw.name}"

  retention_in_days = 30
}

### API
resource "aws_lambda_permission" "send_sms" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_sms.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.ugt_gw.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "post_sms" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  integration_uri    = aws_lambda_function.send_sms.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "post_sms" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  route_key = "POST /api/v1/sms"
  target    = "integrations/${aws_apigatewayv2_integration.post_sms.id}"
}

### Lambda
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

### Backend Domain
resource "aws_apigatewayv2_domain_name" "backend" {
  domain_name = local.api_domain_name

  domain_name_configuration {
    certificate_arn = module.acm.acm_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "live" {
  api_id          = aws_apigatewayv2_api.ugt_gw.id
  domain_name     = aws_apigatewayv2_domain_name.backend.id
  stage           = aws_apigatewayv2_stage.ugt_gw_stage.id
  api_mapping_key = aws_apigatewayv2_stage.ugt_gw_stage.name
}

resource "cloudflare_record" "backend" {
  zone_id = data.cloudflare_zone.this.id
  name    = var.api_subdomain
  type    = "CNAME"
  value   = aws_apigatewayv2_domain_name.backend.domain_name_configuration[0].target_domain_name
  ttl     = 1
  proxied = true

  allow_overwrite = true
}