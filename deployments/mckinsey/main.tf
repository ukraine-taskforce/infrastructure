module "mckinsey" {
  source = "../../modules/mckinsey"

  region      = var.region
  env_name    = var.env_name
  domain_name = var.domain_name
  subdomain   = var.subdomain

  github_oidc_trusted_repos = var.github_oidc_trusted_repos
}

