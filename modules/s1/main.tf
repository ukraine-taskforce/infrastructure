provider "aws" {
  region = var.region
}

locals {
  api_domain_name = join(".", [var.api_subdomain, var.domain_name])
}

### VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  enable_ipv6 = true

  name = join("-", [var.env_name, var.region, "vpc"])
  cidr = "10.0.0.0/16"

  azs             = [join([var.region, "a"]), join([var.region, "b"]), join([var.region, "c"])]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  one_nat_gateway_per_az = false
}

### ACM
module "acm" {
  source = "terraform-aws-modules/acm/aws"

  domain_name = var.domain_name
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

### Backend API Gateway
resource "aws_apigatewayv2_api" "ugt_gw" {
  name          = join("-", [var.env_name, var.region, "api-gateway"])
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = [join("", ["https://", var.domain_name])]
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

//Bot webhook API
resource "aws_lambda_permission" "bot_webhook" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bot_client.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.ugt_gw.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "bot_webhook" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  integration_uri    = aws_lambda_function.bot_client.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "bot_webhook" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  route_key = "POST /${random_id.both_path.hex}/webhook"
  target    = "integrations/${aws_apigatewayv2_integration.bot_webhook.id}"
}

resource "random_id" "both_path" {
  byte_length = 16
}

//Bot send_message API
resource "aws_lambda_permission" "bot_send_message" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bot_client.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.ugt_gw.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "bot_send_message" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  integration_uri    = aws_lambda_function.bot_client.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "bot_send_message" {
  api_id = aws_apigatewayv2_api.ugt_gw.id
  route_key = "POST /${random_id.both_path.hex}/send_message"
  target    = "integrations/${aws_apigatewayv2_integration.bot_send_message.id}"
}

//Incidents API
resource "aws_lambda_permission" "incidents" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.incidents.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.ugt_gw.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "get_incidents" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  integration_uri    = aws_lambda_function.incidents.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_incidents" {
  api_id = aws_apigatewayv2_api.ugt_gw.id

  route_key = "GET /api/v1/incident"
  target    = "integrations/${aws_apigatewayv2_integration.get_incidents.id}"
}

### Backend Lambda
//Bot API
resource "aws_lambda_function" "bot_client" {
  function_name = "PostBotMessage"

  s3_bucket = aws_s3_bucket.ugt_lambda_states.id
  s3_key    = var.lambda_bot_client_key

  timeout = 30
  handler = "main.lambda_handler"
  runtime = "python3.9"

  role = aws_iam_role.bot_incident_lambda_policy.arn

  environment {
    variables = {
      domain                    = aws_apigatewayv2_api.ugt_gw.api_endpoint
      path_key                  = random_id.both_path.hex
      token_parameter           = aws_secretsmanager_secret.telegram_token.arn
      incident_state_table_name = aws_dynamodb_table.incidents.name
      sqs_url                   = aws_sqs_queue.incidents-queue.url
    }
  }
}

resource "aws_cloudwatch_log_group" "bot_client" {
  name = "/aws/lambda/${aws_lambda_function.bot_client.function_name}"

  retention_in_days = 30
}

//Incident API
resource "aws_lambda_function" "incidents" {
  function_name = "GetIncident"

  s3_bucket = aws_s3_bucket.ugt_lambda_states.id
  s3_key    = var.lambda_incidents_key

  runtime = "nodejs14.x"
  handler = "index.handler"

  role = aws_iam_role.read_incident_lambda_policy.arn

  environment {
    variables = {
      SECRET_ARN : aws_secretsmanager_secret.rds_credentials.arn,
      RDS_DB_ARN : aws_rds_cluster.incidents.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "incidents" {
  name = "/aws/lambda/${aws_lambda_function.incidents.function_name}"

  retention_in_days = 30
}

//SQS listener
resource "aws_lambda_function" "processor" {
  function_name = "SaveIncident"

  s3_bucket = aws_s3_bucket.ugt_lambda_states.id
  s3_key    = var.lambda_processor_key

  runtime = "nodejs14.x"
  handler = "index.handler"

  role = aws_iam_role.store_incident_lambda_policy.arn

  timeout = 30

  environment {
    variables = {
      SECRET_ARN : aws_secretsmanager_secret.rds_credentials.arn,
      RDS_DB_ARN : aws_rds_cluster.incidents.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "listener" {
  name = "/aws/lambda/${aws_lambda_function.processor.function_name}"

  retention_in_days = 30
}

# Event source from SQS
resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.incidents-queue.arn
  enabled          = true
  function_name    = aws_lambda_function.processor.arn
  batch_size       = 1
}

### Backend DyamoDB
resource "aws_dynamodb_table" "incidents" {
  name         = join("-", [var.env_name, var.region, "dynamodb-incidents"])
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

### Backend RDS
resource "aws_rds_cluster" "incidents" {
  name = join("-", [var.env_name, var.region, "dynamodb-incidents"])

  engine                  = "aurora-postgresql"
  engine_mode             = "serverless"
  enable_http_endpoint    = "true"
  availability_zones      = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  backup_retention_period = 5
  preferred_backup_window = "04:00-05:00"
  deletion_protection     = true

  cluster_identifier = "reporting-incidents-serverless"
  database_name      = "postgres"
  master_username    = "root"
  master_password    = random_password.rds_master_password.result

  scaling_configuration {
    max_capacity = 4
    min_capacity = 2
  }
}

### Backend IAM
resource "aws_iam_policy" "bot_incident_lambda_policy" {
  name        = "bot_incident_lambda_policy"
  description = "bot_incident_lambda_policy"

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
      "Resource": "${aws_sqs_queue.incidents-queue.arn}"
    },
    {
      "Action": [
        "dynamodb:PutItem"
      ],
      "Effect": "Allow",
      "Resource": "${aws_dynamodb_table.incidents.arn}"
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

resource "aws_iam_role" "bot_incident_lambda_policy" {
  name               = "bot_incident_lambda_policy"
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

resource "aws_iam_role_policy_attachment" "bot_incident_lambda_policy_attachment" {
  role       = aws_iam_role.bot_incident_lambda_policy.id
  policy_arn = aws_iam_policy.bot_incident_lambda_policy.arn
}

resource "aws_iam_policy" "store_incident_lambda_policy" {
  name        = "store_incident_lambda_policy"
  description = "store_incident_lambda_policy"

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
      "Resource": "${aws_sqs_queue.incidents-queue.arn}"
    },
    {
      "Action": [
        "rds-data:ExecuteStatement",
        "rds-data:RollbackTransaction",
        "rds-data:CommitTransaction",
        "rds-data:ExecuteSql",
        "rds-data:BatchExecuteStatement",
        "rds-data:BeginTransaction"
      ],
      "Effect": "Allow",
      "Resource": "${aws_rds_cluster.incidents.arn}"
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

resource "aws_iam_role" "store_incident_lambda_policy" {
  name               = "store_incident_lambda_policy"
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

resource "aws_iam_role_policy_attachment" "store_incident_lambda_policy_attachment" {
  role       = aws_iam_role.store_incident_lambda_policy.id
  policy_arn = aws_iam_policy.store_incident_lambda_policy.arn
}

resource "aws_iam_policy" "read_incident_lambda_policy" {
  name        = "store_incident_lambda_policy"
  description = "store_incident_lambda_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "rds-data:ExecuteStatement",
        "rds-data:RollbackTransaction",
        "rds-data:CommitTransaction",
        "rds-data:ExecuteSql",
        "rds-data:BatchExecuteStatement",
        "rds-data:BeginTransaction"
      ],
      "Effect": "Allow",
      "Resource": "${aws_rds_cluster.incidents.arn}" TODO
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

resource "aws_iam_role" "read_incident_lambda_policy" {
  name               = "read_incident_lambda_policy"
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
  role       = aws_iam_role.read_incident_lambda_policy.id
  policy_arn = aws_iam_policy.read_incident_lambda_policy.arn
}

### Backend S3
resource "aws_s3_bucket" "ugt_lambda_states" {
  bucket = join("-", [var.env_name, var.region, "lambda-states"])

  force_destroy = true
}

### Backend SQS
resource "aws_sqs_queue" "incidents-queue" {
  name                      = join("-", [var.env_name, var.region, "sqs-incidents-queue"])
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
}

### Secrets


resource "aws_secretsmanager_secret" "telegram_token" {
  name = "lambda/telegram-bot-client/token"
}

resource "aws_secretsmanager_secret_version" "telegram_token" {
  secret_id = aws_secretsmanager_secret.telegram_token.id
  secret_string = var.telegram_token
}

resource "random_password" "rds_master_password" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "rds/aurora/${aws_rds_cluster.incidents.cluster_identifier}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id     = aws_secretsmanager_secret.rds_credentials.id
  secret_string = <<EOF
{
  "username": "${aws_rds_cluster.incidents.master_username}",
  "password": "${random_password.rds_master_password.result}",
  "engine": "postgres",
  "host": "${aws_rds_cluster.incidents.endpoint}",
  "port": ${aws_rds_cluster.incidents.port},
  "dbClusterIdentifier": "${aws_rds_cluster.incidents.cluster_identifier}",
  "database_name": "${aws_rds_cluster.incidents.database_name}"
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
