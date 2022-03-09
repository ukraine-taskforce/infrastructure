data "aws_secretsmanager_secret" "tokens" {
  name = "tokens"
}

data "aws_secretsmanager_secret_version" "tokens" {
  secret_id = data.aws_secretsmanager_secret.tokens.id
}

locals {
  github_oauth_token            = jsondecode(data.aws_secretsmanager_secret_version.tokens.secret_string)["github"]
  terraform_default_version = "0.14.5"
}
