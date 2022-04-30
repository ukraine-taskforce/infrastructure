variable "role_name" {
  type = string
}

variable "assume_role_policy" {
  type = string
}

variable "deploy_policies" {
  type = map(object({
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
}
