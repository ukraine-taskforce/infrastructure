variable "name" {
  type        = string
  description = "API Gateway name"
}

variable "description" {
  type        = string
  default     = ""
  description = "API Gateway description"
}

variable "domain_name" {
  type        = string
  description = "Domain name"
}

variable "domain_name_certificate_arn" {
  type        = string
  description = "Domain name certificate ARN"
}

variable "integrations" {
  type        = map
  description = "Integrations with lambda functions"
}

variable "allow_headers" {
  type        = list
  default     = []
  description = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
}
