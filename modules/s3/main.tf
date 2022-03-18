provider "aws" {
  region = var.region
}

locals {
  fe_domain_name = join(".", [var.fe_subdomain, var.domain_name])
  api_domain_name = join(".", [var.api_subdomain, var.domain_name])
}

### VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  enable_ipv6 = true

  name = join("-", [var.env_name, var.region, "vpc"])
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  one_nat_gateway_per_az = false
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

### Backend API Gateway
resource "aws_apigatewayv2_api" "ugt_gw" {
  name          = join("-", [var.env_name, var.region, "api-gateway"])
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = [var.is_production_env ? join("", ["https://", local.fe_domain_name]) : "*"]
    allow_methods = ["POST", "GET"]
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

### Locations API
resource "aws_lambda_permission" "locations" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.locations.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.ugt_gw.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "get_locations" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  integration_uri    = aws_lambda_function.locations.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_locations" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  route_key = "GET /api/v1/requests/locations"
  target    = "integrations/${aws_apigatewayv2_integration.get_locations.id}"
}

### Supplies API
resource "aws_lambda_permission" "supplies" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.supplies.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.ugt_gw.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "get_supplies" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  integration_uri    = aws_lambda_function.supplies.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_supplies" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  route_key = "GET /api/v1/requests/supplies"
  target    = "integrations/${aws_apigatewayv2_integration.get_supplies.id}"
}

### Requests API
resource "aws_lambda_permission" "requests" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.requests.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.ugt_gw.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "post_request" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  integration_uri    = aws_lambda_function.requests.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "post_request" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  route_key = "POST /api/v1/requests"
  target    = "integrations/${aws_apigatewayv2_integration.post_request.id}"
}

### Requests Aggregated API
resource "aws_lambda_permission" "get_requests_aggregated" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.requests_aggregated.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.ugt_gw.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "get_requests_aggregated" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  integration_uri    = aws_lambda_function.requests_aggregated.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_requests_aggregated" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  route_key = "GET /api/v1/requests/aggregated"
  target    = "integrations/${aws_apigatewayv2_integration.get_requests_aggregated.id}"
}

### Backend Lambda
### Locations API
resource "aws_lambda_function" "locations" {
  function_name = "GetLocations"

  s3_bucket = aws_s3_bucket.ugt_lambda_states.id
  s3_key    = var.lambda_locations_key

  runtime = "nodejs12.x"
  handler = "locations.handler"

  role = aws_iam_role.requests_lambda_role.arn
}

resource "aws_cloudwatch_log_group" "locations" {
  name = "/aws/lambda/${aws_lambda_function.locations.function_name}"

  retention_in_days = 30
}

### Supplies API
resource "aws_lambda_function" "supplies" {
  function_name = "GetSupplies"

  s3_bucket = aws_s3_bucket.ugt_lambda_states.id
  s3_key    = var.lambda_supplies_key

  runtime = "nodejs12.x"
  handler = "supplies.handler"

  role = aws_iam_role.requests_lambda_role.arn
}

resource "aws_cloudwatch_log_group" "supplies" {
  name = "/aws/lambda/${aws_lambda_function.supplies.function_name}"

  retention_in_days = 30
}

### Requests API
resource "aws_lambda_function" "requests" {
  function_name = "PostRequest"

  s3_bucket = aws_s3_bucket.ugt_lambda_states.id
  s3_key    = var.lambda_requests_key

  runtime = "nodejs12.x"
  handler = "requests.handler"

  role = aws_iam_role.post_request_lambda_role.arn

  timeout = 30

  environment {
    variables = {
      sqs_url = aws_sqs_queue.requests-queue.url
    }
  }
}

resource "aws_cloudwatch_log_group" "requests" {
  name = "/aws/lambda/${aws_lambda_function.requests.function_name}"

  retention_in_days = 30
}

### SQS listener
resource "aws_lambda_function" "processor" {
  function_name = "SaveRequest"

  s3_bucket = aws_s3_bucket.ugt_lambda_states.id
  s3_key    = var.lambda_processor_key

  runtime = "nodejs12.x"
  handler = "processor.handler"

  role = aws_iam_role.read_request_lambda_role.arn

  timeout = 30

  environment {
    variables = {
      sqs_url    = aws_sqs_queue.requests-queue.url
      table_name = aws_dynamodb_table.requests.name
    }
  }
}

resource "aws_cloudwatch_log_group" "listener" {
  name = "/aws/lambda/${aws_lambda_function.processor.function_name}"

  retention_in_days = 30
}

### Requests Aggregated API
resource "aws_lambda_function" "requests_aggregated" {
  function_name = "GetRequestsAggregated"

  s3_bucket = aws_s3_bucket.ugt_lambda_states.id
  s3_key    = var.lambda_requests_aggregated_key

  runtime = "nodejs12.x"
  handler = "requests-aggregated.handler"

  role = aws_iam_role.read_request_aggregated_lambda_role.arn

  timeout = 30

  environment {
    variables = {
      bucket   = aws_s3_bucket.ugt_requests_aggregations.bucket
      poolId   = aws_cognito_user_pool.users.id
      clientId = aws_cognito_user_pool_client.cognito_client.id
    }
  }
}

resource "aws_cloudwatch_log_group" "requests_aggregated" {
  name = "/aws/lambda/${aws_lambda_function.requests_aggregated.function_name}"

  retention_in_days = 30
}


# Event source from SQS
resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.requests-queue.arn
  enabled          = true
  function_name    = aws_lambda_function.processor.arn
  batch_size       = 1
}

### Backend DyamoDB
resource "aws_dynamodb_table" "requests" {
  name         = join("-", [var.env_name, var.region, "dynamodb-requests"])
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

### Backend IAM
resource "aws_iam_role" "requests_lambda_role" {
  name = "requests_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "requests_lambda_policy" {
  role       = aws_iam_role.requests_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "post_request_lambda_policy" {
  name        = "post_request_lambda_policy"
  description = "post_request_lambda_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:SendMessage",
        "sqs:GetQueueAttributes"
      ],
      "Effect": "Allow",
      "Resource": "${aws_sqs_queue.requests-queue.arn}"
    },
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "post_request_lambda_role" {
  name               = "post_request_lambda_role"
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

resource "aws_iam_role_policy_attachment" "requests_lambda_policy_attachment" {
  role       = aws_iam_role.post_request_lambda_role.id
  policy_arn = aws_iam_policy.post_request_lambda_policy.arn
}

resource "aws_iam_policy" "read_request_lambda_policy" {
  name        = "read_request_lambda_policy"
  description = "read_request_lambda_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Effect": "Allow",
      "Resource": "${aws_sqs_queue.requests-queue.arn}"
    },
    {
      "Action": [
        "dynamodb:PutItem"
      ],
      "Effect": "Allow",
      "Resource": "${aws_dynamodb_table.requests.arn}"
    },
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "read_request_lambda_role" {
  name               = "read_request_lambda_role"
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

resource "aws_iam_role_policy_attachment" "read_request_lambda_policy_attachment" {
  role       = aws_iam_role.read_request_lambda_role.id
  policy_arn = aws_iam_policy.read_request_lambda_policy.arn
}

resource "aws_iam_policy" "read_request_aggregated_lambda_policy" {
  name        = "read_request_aggregated_lambda_policy"
  description = "read_request_aggregated_lambda_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["s3:Get*", "s3:List*"],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.ugt_requests_aggregations.arn}",
        "${aws_s3_bucket.ugt_requests_aggregations.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "read_request_aggregated_lambda_role" {
  name = "read_request_aggregated_lambda_role"
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

resource "aws_iam_role_policy_attachment" "read_request_aggregated_lambda_role" {
  role = aws_iam_role.read_request_aggregated_lambda_role.id
  policy_arn = aws_iam_policy.read_request_aggregated_lambda_policy.arn
}

### Backend S3
resource "aws_s3_bucket" "ugt_lambda_states" {
  bucket = join("-", [var.env_name, var.region, "lambda-states"])

  force_destroy = true
}

### Backend SQS

resource "aws_sqs_queue" "requests-queue" {
  name                      = join("-", [var.env_name, var.region, "sqs-requests-queue"])
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
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

resource "cloudflare_record" "backend" {
  zone_id = data.cloudflare_zone.this.id
  name    = var.api_subdomain
  type    = "CNAME"
  value   = aws_apigatewayv2_domain_name.backend.domain_name_configuration[0].target_domain_name
  ttl     = 1
  proxied = true

  allow_overwrite = true
}

resource "aws_apigatewayv2_api_mapping" "live" {
  api_id          = aws_apigatewayv2_api.ugt_gw.id
  domain_name     = aws_apigatewayv2_domain_name.backend.id
  stage           = aws_apigatewayv2_stage.ugt_gw_stage.id
  api_mapping_key = aws_apigatewayv2_stage.ugt_gw_stage.name
}

### Authentication
resource "aws_cognito_user_pool" "users" {
  name = join("-", [var.env_name, var.region, "pool"])

  
  mfa_configuration = "OFF"

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = true

    invite_message_template {
      email_message = "You were invited to Ukraine Global Taskforce maps application.\n\nYour username is {username} and password is {####}."
      email_subject = "Your Ukraine Global Taskforce password"
      sms_message   = "Your Ukraine Global Taskforce username is {username} and password is {####}."
    }
  }
}

resource "aws_cognito_user_pool_client" "cognito_client" {
  name = join("-", [var.env_name, var.region, "cognito-client"])

  user_pool_id = aws_cognito_user_pool.users.id
}