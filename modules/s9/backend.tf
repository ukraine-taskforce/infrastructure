### Backend Lambdas
resource "aws_lambda_function" "supply_data" {

  function_name = "SupplyData"
  description = "Converts CSV data and supplies it to DynamoDB"

  s3_bucket = aws_s3_bucket.ugt_lambda_states.id
  s3_key    = var.lambda_supply_data_key

  handler = "main.lambda_handler"
  runtime = "python3.9"

  role = aws_iam_role.supply_data_role.arn
}

### IAM Roles
resource "aws_iam_role" "supply_data_role" {
  name = "supply_data_role"

  assume_role_policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "lambda.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
  EOF
}

resource "aws_iam_role_policy_attachment" "supply_data_lambda_policy_attachment" {
  role       = aws_iam_role.supply_data_role.id
  policy_arn = aws_iam_policy.supply_data_lambda_policy.arn
}

resource "aws_iam_policy" "supply_data_lambda_policy" {
  name        = "supply_data_lambda_policy"
  description = "supply_data_lambda_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:PutItem"
      ],
      "Effect": "Allow",
      "Resource": "${aws_dynamodb_table.sos-info.arn}"
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

### Backend DynamoDB
resource "aws_dynamodb_table" "sos-info" {
  name = join("-", [var.env_name, var.region, "sos-info"])
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "ID"

  attribute {
    name = "ID"
    type = "S"
  }
}