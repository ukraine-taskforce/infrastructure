provider "aws" {
  region = var.region

  default_tags {
    tags = {
      env_name = var.env_name
    }
  }
}

locals {
  fe_domain_name  = join(".", [var.fe_subdomain, var.domain_name])
  api_domain_name = join(".", [var.api_subdomain, var.domain_name])
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

# Rewrite known non-root paths to root index
resource "cloudflare_ruleset" "transform_uri_rule_path" {
  zone_id     = data.cloudflare_zone.this.id
  name        = "${local.fe_domain_name} root index"
  description = "redirect non-root paths to root index"
  kind        = "zone"
  phase       = "http_request_transform"

  rules {
    action = "rewrite"
    action_parameters {
      uri {
        path {
          value = "/"
        }
      }
    }

    expression  = "(http.host eq \"${local.fe_domain_name}\" and (http.request.uri.path eq \"/ua\" or http.request.uri.path eq \"/hu\" or http.request.uri.path eq \"/pl\" or http.request.uri.path eq \"/ro\" or http.request.uri.path eq \"/md\") )"
    description = "${local.fe_domain_name} root index"
    enabled     = true
  }
}

### Backend S3
resource "aws_s3_bucket" "ugt_lambda_states" {
  bucket = join("-", [var.env_name, var.region, "lambda-states"])

  force_destroy = true
}
