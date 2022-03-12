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
