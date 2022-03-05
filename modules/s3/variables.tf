variable "name" {
  type        = string
  description = "S3 bucket name"
}

variable "acl {
  type        = string
  default     = "private"
  description = "S3 bucket ACL"
}
