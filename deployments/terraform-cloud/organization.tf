resource "tfe_organization" "ugt" {
  name                     = "ugt"
  email                    = "rcoliveirag@gmail.com"
  collaborator_auth_policy = "password"
}

resource "tfe_oauth_client" "github" {
  organization     = tfe_organization.ugt.id
  api_url          = "https://api.github.com"
  http_url         = "https://github.com"
  oauth_token      = local.github_oauth_token
  service_provider = "github"
}
