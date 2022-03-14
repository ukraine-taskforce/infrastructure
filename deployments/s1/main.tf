module "s1" {
  source = "../../modules/s1"

  region = var.region
  env_name = var.env_name
  domain_name = var.domain_name
  api_subdomain = var.api_subdomain
}

