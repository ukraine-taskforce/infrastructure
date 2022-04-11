module "s2" {
  source = "../../modules/s2"

  region                    = var.region
  env_name                  = var.env_name
  is_production_env         = var.is_production_env
  domain_name               = var.domain_name
  fe_subdomain              = var.fe_subdomain
  api_subdomain             = var.api_subdomain
  github_oidc_trusted_repos = var.github_oidc_trusted_repos
}

