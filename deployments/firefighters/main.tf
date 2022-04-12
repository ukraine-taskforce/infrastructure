module "firefighters" {
  source = "../../modules/firefighters"

  region                    = var.region
  env_name                  = var.env_name
  domain_name               = var.domain_name
  fe_subdomain              = var.fe_subdomain
  github_oidc_trusted_repos = var.github_oidc_trusted_repos
}

