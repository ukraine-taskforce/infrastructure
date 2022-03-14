module "s3" {
  source = "../../modules/s3"

  region = var.region
  env_name = var.env_name
  is_production_env = var.is_production_env
  domain_name = var.domain_name
  api_subdomain = var.api_subdomain
  fe_subdomain = var.fe_subdomain
  github_oidc_trusted_repos = var.github_oidc_trusted_repos
}
