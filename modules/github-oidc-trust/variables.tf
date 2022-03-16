variable "trusted_repos" {
  type        = list(string)
  description = "Repos in which workflows are allowed to retrieve temp. credentials from AWS"
}

variable "github_org" {
  type        = string
  default     = "ukraine-taskforce"
  description = "Name of the GitHub organization"
}
