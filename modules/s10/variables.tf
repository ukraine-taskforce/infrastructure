variable "region" {
  description = "Region"
  type        = string
}

variable "env_name" {
  description = "Environment name"
  type        = string
}

variable "is_production_env" {
  description = "Defines if this is a production deployment"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Root Domain name"
  type        = string
}

variable "api_subdomain" {
  description = "API Subdomain"
  type        = string
}

variable "fe_subdomain" {
  description = "Frontend Subdomain"
  type        = string
}

variable "github_oidc_trusted_repos" {
  type        = list(string)
  description = "Repos in which workflows are allowed to retrieve temp. credentials from AWS"
}