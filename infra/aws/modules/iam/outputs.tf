output "github_actions_role_arn" {
  description = "IAM role ARN — set as AWS_OIDC_ROLE_ARN GitHub Actions secret"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  value = aws_iam_role.github_actions.name
}
