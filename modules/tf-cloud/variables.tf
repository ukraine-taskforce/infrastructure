variable "workspace_name" {}

variable "tfe_organization_id" {
  default = "UGT"
}

variable "allow_destroy_plan" {
  default = true
}

variable "auto_apply" {
  default = true
}

variable "terraform_version" {
  default = "0.14.5"
}

variable "vcs_repo_identifier" {
  default = "ukraine-taskforce/infrastructure"
}

variable "vcs_repo_oauth_token_id" {}

variable "sensitive_vars" {
  type        = map(any)
  default     = {}
  description = "Map with sensitive env vars to use in this workspace"
}

variable "structured_run_output_enabled" {
  default     = false
  description = "Whether this workspace should show output from Terraform runs using the enhanced UI when available"
}

variable "non_sensitive_vars" {
  type        = map(any)
  default     = {}
  description = "Map with non sensitive env vars to use in this workspace"
}

variable "directory" {
  type        = string
  description = "Directory the terraform manifests are in"
}
