resource "aws_s3_bucket" "ugt_glue_scripts" {
  bucket = join("-", [
    var.env_name,
    var.region,
    "ugt-glue-scripts"])

  force_destroy = true
}

resource "aws_s3_bucket" "ugt_requests_aggregations" {
  bucket = join("-", [
    var.env_name,
    var.region,
    "ugt-requests-aggregations"])

  force_destroy = true
}

resource "aws_iam_policy" "requests_etl_policy" {
  name = "requests_etl_policy"
  description = "requests_etl_policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "${aws_s3_bucket.ugt_glue_scripts.arn}*",
                "${aws_s3_bucket.ugt_requests_aggregations.arn}*",
                "${aws_s3_bucket.ugt_glue_scripts.arn}/*",
                "${aws_s3_bucket.ugt_requests_aggregations.arn}/*"
            ]
        },
        {
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:DescribeTable",
                "dynamodb:Scan"
            ],
            "Effect": "Allow",
            "Resource": "${aws_dynamodb_table.requests.arn}"
        },
        {
            "Action": [
                "glue:CreateJob"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "requests_etl_role" {
  name = "requests_etl_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "requests_etl_policy_attachment" {
  role = aws_iam_role.requests_etl_role.id
  policy_arn = aws_iam_policy.requests_etl_policy.arn
}

resource "aws_iam_role_policy_attachment" "requests_etl_policy_attachment_glue" {
  role = aws_iam_role.requests_etl_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_glue_job" "request_aggregator" {
  name = "request-aggregator"
  role_arn = aws_iam_role.requests_etl_role.arn
  max_retries = 1
  timeout = 60
  number_of_workers = 4
  worker_type = "Standard"
  glue_version = "3.0"

  command {
    script_location = "s3://${aws_s3_bucket.ugt_glue_scripts.bucket}/requestsAggregation.py"
    python_version = 3
  }

  default_arguments = {
    "--bucket" = aws_s3_bucket.ugt_requests_aggregations.bucket
    "--table_name" = aws_dynamodb_table.requests.name
  }
}

resource "aws_glue_trigger" "request_aggregator" {
  name = "example"
  schedule = "cron(0 * ? * * *)"
  type = "SCHEDULED"

  actions {
    job_name = aws_glue_job.request_aggregator.name
  }
}
