variable "region" {
  description = "Region"
  type = string
  default = "eu-central-1"
}

variable "env_name" {
  description = "Environment name"
  type = string
}

variable "domain_name" {
  description = "Root Domain name"
  type = string
}

variable "fe_subdomain" {
  description = "Frontend Subdomain"
  type = string
}