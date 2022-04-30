data "aws_iam_policy_document" "this" {
  dynamic "statement" {
    for_each = var.deploy_policies
    content {
      sid       = statement.key
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_policy" "this" {
  name   = var.role_name
  policy = data.aws_iam_policy_document.this.json
}

# Use this role in your GitHub Actions workflows
resource "aws_iam_role" "this" {
  name = var.role_name

  assume_role_policy = var.assume_role_policy

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.id
  policy_arn = aws_iam_policy.this.arn
}
