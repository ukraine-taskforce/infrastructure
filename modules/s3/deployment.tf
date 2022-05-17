module "github_oidc_trust" {
  source = "../github-oidc-trust"

  trusted_repos = var.github_oidc_trusted_repos
}

data "aws_iam_policy_document" "deploy_permissions" {
  statement {
    sid = "AllowS3Sync"

    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [
      module.frontend.s3_bucket_arn,
      aws_s3_bucket.ugt_lambda_states.arn,
      aws_s3_bucket.ugt_glue_scripts.arn,
      aws_s3_bucket.ugt_requests_aggregations.arn,
      "${module.frontend.s3_bucket_arn}/*",
      "${aws_s3_bucket.ugt_lambda_states.arn}/*",
      "${aws_s3_bucket.ugt_glue_scripts.arn}/*",
      "${aws_s3_bucket.ugt_requests_aggregations.arn}/*"

    ]
  }
  statement {
    sid = "AllowLambdaUpdateFunctionCode"

    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunctionConfiguration"
    ]
    resources = [
      aws_lambda_function.locations.arn,
      aws_lambda_function.processor.arn,
      aws_lambda_function.requests.arn,
      aws_lambda_function.supplies.arn,
      aws_lambda_function.requests_aggregated.arn,
      aws_lambda_function.send_sms.arn
    ]
  }
}

resource "aws_iam_policy" "deploy" {
  name   = join("-", [var.env_name, var.region, "deploy"])
  policy = data.aws_iam_policy_document.deploy_permissions.json
}

# Use this role in your GitHub Actions workflows
resource "aws_iam_role" "deploy" {
  name = join("-", [var.env_name, var.region, "deploy"])

  assume_role_policy = module.github_oidc_trust.trust_policy_document

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.deploy.id
  policy_arn = aws_iam_policy.deploy.arn
}
