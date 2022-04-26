module "s10" {
  source = "../../modules/s10"

  region = var.region
  env_name = var.env_name
  domain_name = var.domain_name
  fe_subdomain = var.fe_subdomain
}

