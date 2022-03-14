output "trust_policy_document" {
  description = "Policy document for IAM roles that trust the GitHub OIDC provider"
  value       = data.aws_iam_policy_document.this.json
}
