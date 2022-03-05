# data "aws_secretsmanager_secret" "tokens" {
#   name = "tokens"
# }

# data "aws_secretsmanager_secret_version" "tokens" {
#   secret_id = data.aws_secretsmanager_secret.tokens.id
# }

locals {
  # cloudflare_api_token          = jsondecode(data.aws_secretsmanager_secret_version.tokens.secret_string)["cloudflare"]
  # aws_access_key_id             = jsondecode(data.aws_secretsmanager_secret_version.tokens.secret_string)["terraform_cloud_aws_access_key_id"]
  # aws_secret_access_key         = jsondecode(data.aws_secretsmanager_secret_version.tokens.secret_string)["terraform_cloud_aws_secret_access_key"]
  github_oauth_token            = "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"
  terraform_default_version = "0.14.5"
}
