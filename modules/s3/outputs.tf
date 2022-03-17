output "vpc_id" {
    description = "The VPC ID"
    value = module.vpc.vpc_id
}

output "deployment_role_arn" {
    description = "ARN of deployment role used by GitHub Actions"
    value = aws_iam_role.deploy.arn
}
