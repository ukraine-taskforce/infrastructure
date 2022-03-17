variable "region" {
  description = "Region"
  type = string
}

variable "env_name" {
  description = "Environment name"
  type = string
}

variable "domain_name" {
  description = "Root Domain name"
  type = string
}

variable "api_subdomain" {
  description = "API Subdomain"
  type = string
}

variable "lambda_bot_client_key" {
  description = "S3 Object key for Telegram Bot lambda"
  type = string
  default = "locations.zip"
}

variable "lambda_incidents_key" {
  description = "S3 Object key for Incidents lambda"
  type = string
  default = "supplies.zip"
}

variable "lambda_processor_key" {
  description = "S3 Object key for Processor lambda"
  type = string
  default = "processor.zip"
}

variable "telegram_token" {
  type      = string
  sensitive = true
  description = "Telegram generated token"
}

variable "acl" {
  type        = string
  default     = "private"
  description = "S3 bucket ACL"
}
