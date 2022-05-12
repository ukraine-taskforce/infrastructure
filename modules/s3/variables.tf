variable "region" {
  description = "Region"
  type = string
}

variable "env_name" {
  description = "Environment name"
  type = string
}

variable "is_production_env" {
  description = "Defines if this is a production deployment"
  type = bool
  default = true
}

variable "domain_name" {
  description = "Root Domain name"
  type = string
}

variable "api_subdomain" {
  description = "API Subdomain"
  type = string
}

variable "fe_subdomain" {
  description = "Frontend Subdomain"
  type = string
}

variable "cors_allow_origins" {
  description = "Other origins that are allowed to hit the s3 API, format: `http(s)://foo.bar`"
  type        = list(string)
  default     = []
}

variable "lambda_locations_key" {
  description = "S3 Object key for Locations lambda"
  type = string
  default = "locations.zip"
}

variable "lambda_supplies_key" {
  description = "S3 Object key for Supplies lambda"
  type = string
  default = "supplies.zip"
}

variable "lambda_requests_key" {
  description = "S3 Object key for Requests lambda"
  type = string
  default = "requests.zip"
}

variable "lambda_requests_list_key" {
  description = "S3 Object key for Requests lambda"
  type = string
  default = "requests-list.zip"
}

variable "lambda_processor_key" {
  description = "S3 Object key for Processor lambda"
  type = string
  default = "processor.zip"
}

variable "lambda_requests_aggregated_key" {
  description = "S3 Object key for Requests Aggregated lambda"
  type = string
  default = "requests-aggregated.zip"
}

variable "acl" {
  type        = string
  default     = "private"
  description = "S3 bucket ACL"
}

variable "github_oidc_trusted_repos" {
  type        = list(string)
  description = "Repos in which workflows are allowed to retrieve temp. credentials from AWS"
}
