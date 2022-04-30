module "frontend" {
  source      = "../frontend-s3"

  domain_name = var.domain_name
  subdomain   = var.subdomain
}

module "github_oidc_trust" {
  source = "../github-oidc-trust"

  trusted_repos = var.github_oidc_trusted_repos
}

module "deploy_role" {
  source = "../deployment-role"

  role_name = join("-", [var.env_name, var.region, "deploy"])
  deploy_policies = {
    AllowS3Sync = {
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
        "${module.frontend.s3_bucket_arn}/*"
      ]
    }
  }

  assume_role_policy = module.github_oidc_trust.trust_policy_document
}
