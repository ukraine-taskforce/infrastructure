### Assuming an IAM role via the GitHub OIDC identity provider in GitHub actions
# https://github.com/aws-actions/configure-aws-credentials#assuming-a-role
# https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
# https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html
resource "aws_iam_openid_connect_provider" "this" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "this" {
  statement {
    sid = "TrustGitHubOIDC"

    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      identifiers = [aws_iam_openid_connect_provider.this.arn]
      type        = "Federated"
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # This is crucial, without this condition any action (even outside of our org)
      # can assume any IAM role with such a trust policy
      values = [for repo in var.trusted_repos: "repo:${var.github_org}/${repo}:*"]
    }
  }
}
