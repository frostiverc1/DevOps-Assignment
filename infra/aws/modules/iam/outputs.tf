output "github_actions_role_arn" {
  description = "IAM role ARN — set as AWS_ROLE_ARN_DEV GitHub Actions secret"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  value = aws_iam_role.github_actions.name
}
