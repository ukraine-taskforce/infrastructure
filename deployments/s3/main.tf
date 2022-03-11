module "s3" {
  source = "../../modules/s3"

  region = var.region
  env_name = var.env_name
  prod = var.prod
  domain_name = var.domain_name
  api_subdomain = var.api_subdomain
  fe_subdomain = var.fe_subdomain
}

