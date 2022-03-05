resource "tfe_workspace" "this" {
  name         = var.workspace_name
  organization = var.tfe_organization_id

  execution_mode     = "remote"
  allow_destroy_plan = var.allow_destroy_plan
  auto_apply         = var.auto_apply
  terraform_version  = var.terraform_version

  trigger_prefixes              = [var.directory]
  working_directory             = var.directory
  structured_run_output_enabled = var.structured_run_output_enabled

  vcs_repo {
    identifier     = var.vcs_repo_identifier
    oauth_token_id = var.vcs_repo_oauth_token_id
  }
}

resource "tfe_variable" "sensitive" {
  for_each     = var.sensitive_vars
  key          = upper(each.key)
  value        = each.value
  sensitive    = true
  category     = "env"
  workspace_id = tfe_workspace.this.id
  description  = upper(each.key)
}

resource "tfe_variable" "non_sensitive" {
  for_each     = var.non_sensitive_vars
  key          = upper(each.key)
  value        = each.value
  sensitive    = false
  category     = "env"
  workspace_id = tfe_workspace.this.id
  description  = upper(each.key)
}
