module "s5" {
  source = "../../modules/s5"

  region = var.region
  env_name = var.env_name
  domain_name = var.domain_name
}

