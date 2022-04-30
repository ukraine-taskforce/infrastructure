variable "region" {
  description = "Region"
  type        = string
}

variable "env_name" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Root Domain name"
  type        = string
}

variable "subdomain" {
  description = "Donations Dashboard subdomain"
  type        = string
}

variable "github_oidc_trusted_repos" {
  type        = list(string)
  description = "Repos in which workflows are allowed to retrieve temp. credentials from AWS"
}
