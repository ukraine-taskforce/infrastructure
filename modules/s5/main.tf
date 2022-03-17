provider "aws" {
  region = var.region
}

locals {
  fe_domain_name = join(".", [var.fe_subdomain, var.domain_name])
}

### VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  enable_ipv6 = true

  name = join("-", [var.env_name, var.region, "vpc"])
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  one_nat_gateway_per_az = false
}

### ACM
module "acm" {
  source = "terraform-aws-modules/acm/aws"

  domain_name = local.fe_domain_name
  zone_id     = data.cloudflare_zone.this.id

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

### Frontend S3 Bucket
module "frontend" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket        = local.fe_domain_name
  acl           = "private"
  attach_policy = true
  policy        = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${local.fe_domain_name}/*",
            "Condition": {
                "IpAddress": {
                    "aws:SourceIp": [
                        "2400:cb00::/32",
                        "2606:4700::/32",
                        "2803:f800::/32",
                        "2405:b500::/32",
                        "2405:8100::/32",
                        "2a06:98c0::/29",
                        "2c0f:f248::/32",
                        "173.245.48.0/20",
                        "103.21.244.0/22",
                        "103.22.200.0/22",
                        "103.31.4.0/22",
                        "141.101.64.0/18",
                        "108.162.192.0/18",
                        "190.93.240.0/20",
                        "188.114.96.0/20",
                        "197.234.240.0/22",
                        "198.41.128.0/17",
                        "162.158.0.0/15",
                        "172.64.0.0/13",
                        "131.0.72.0/22",
                        "104.16.0.0/13",
                        "104.24.0.0/14"
                    ]
                }
            }
        }
    ]
}
POLICY

  website = {
    index_document = "index.html"
    error_document = "index.html"
  }
}

resource "cloudflare_record" "frontend" {
  zone_id = data.cloudflare_zone.this.id
  name    = var.fe_subdomain
  type    = "CNAME"
  value   = module.frontend.s3_bucket_website_endpoint
  ttl     = 1
  proxied = true

  allow_overwrite = true
}

### Authentication
resource "aws_cognito_user_pool" "users" {
  name = join("-", [var.env_name, var.region, "pool"])

  
  mfa_configuration = "OFF"

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
  }
}

resource "aws_cognito_user_pool_client" "cognito-client" {
  name = join("-", [var.env_name, var.region, "cognito-client"])

  user_pool_id = aws_cognito_user_pool.users.id
}