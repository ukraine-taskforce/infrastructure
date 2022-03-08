module "s3" {
  source = "../../modules/tf-cloud"

  workspace_name          = "s3-production"
  vcs_repo_oauth_token_id = tfe_oauth_client.github.oauth_token_id

  directory = "deployments/s3"

  sensitive_vars = {
    # github_token          = local.github_oauth_token
    # aws_access_key_id     = local.aws_access_key_id
    # aws_secret_access_key = local.aws_secret_access_key
  }
}
