provider "aws" {
  region = var.region
}

locals {
  env_domain_name = var.production ? var.domain_name : join(".", ["dev", var.domain_name])
}

# VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  enable_ipv6 = true

  name = join("-", [var.env_name, var.region, "vpc"])
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
}

# ACM 
module "acm" {
  source = "terraform-aws-modules/acm/aws"

  domain_name = local.env_domain_name
  zone_id     = data.cloudflare_zone.this.id

  subject_alternative_names = [
    "*.${local.env_domain_name}",
  ]

  create_route53_records  = false
  validation_record_fqdns = cloudflare_record.validation.*.hostname
}

resource "cloudflare_record" "validation" {
  count = length(module.acm.distinct_domain_names)

  zone_id = data.cloudflare_zone.this.id
  name    = element(module.acm.validation_domains, count.index)["resource_record_name"]
  type    = element(module.acm.validation_domains, count.index)["resource_record_type"]
  value   = replace(element(module.acm.validation_domains, count.index)["resource_record_value"], "/.$/", "")
  ttl     = 60
  proxied = false

  allow_overwrite = true
}

data "cloudflare_zone" "this" {
  name = var.domain_name
}