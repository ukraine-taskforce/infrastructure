variable "region" {
  description = "Region"
  type = string
}

variable "env_name" {
  description = "Environment name"
  type = string
}

variable "domain_name" {
  description = "Domain name"
  type = string
}

variable "production" { 
  description = "Specifies whether this is a production deployment"
  type = bool
}