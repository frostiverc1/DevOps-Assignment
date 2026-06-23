terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix     = "${var.project}-${var.environment}"
  github_oidc_url = "token.actions.githubusercontent.com"
  github_oidc_aud = "sts.amazonaws.com"
}

# ── GitHub Actions OIDC Identity Provider ────────────────────────────────────
# GitHub's OIDC thumbprint (SHA-1 of the root CA cert) — stable value.
# See: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments

data "aws_iam_openid_connect_provider" "github" {
  # Try to reference an existing OIDC provider before creating one.
  # The provider is global (not per-env), so we use a data source to avoid
  # duplicate resource errors when multiple environments share one account.
  url = "https://${local.github_oidc_url}"
}

# Create OIDC provider only if it does not already exist.
# In practice: run bootstrap (which creates it) before any environment apply.
# Keeping it here as reference
# comment out if already created by bootstrap.

# resource "aws_iam_openid_connect_provider" "github" {
#   url             = "https://${local.github_oidc_url}"
#   client_id_list  = [local.github_oidc_aud]
#   thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1",
#                      "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
# }

# ── IAM Role: GitHub Actions Deploy ──────────────────────────────────────────
# Trust policy scoped to this specific repository only (sub claim).
# No static access keys are created.

resource "aws_iam_role" "github_actions" {
  name = "${local.name_prefix}-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.github_oidc_url}:aud" = local.github_oidc_aud
        }
        StringLike = {
          # Scoped to this specific repo and any branch/event
          "${local.github_oidc_url}:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })

  tags = { Environment = var.environment, Project = var.project }
}

# ── ECR permissions ───────────────────────────────────────────────────────────

resource "aws_iam_role_policy" "ecr" {
  name = "${local.name_prefix}-ecr-push"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:BatchGetImage"
        ]
        Resource = [
          "arn:aws:ecr:ap-south-1:${var.aws_account_id}:repository/${var.project}-frontend",
          "arn:aws:ecr:ap-south-1:${var.aws_account_id}:repository/${var.project}-backend"
        ]
      }
    ]
  })
}

# ── ECS deploy permissions ─────────────────────────────────────────────────────

resource "aws_iam_role_policy" "ecs_deploy" {
  name = "${local.name_prefix}-ecs-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:ListTaskDefinitions"
        ]
        Resource = "*"
      },
      {
        # PassRole scoped to the specific task execution role only
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = var.task_execution_role_arn
      }
    ]
  })
}

# ── Terraform state access (for infra CI/CD workflow) ─────────────────────────

resource "aws_iam_role_policy" "tf_state" {
  name = "${local.name_prefix}-tf-state-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.state_bucket_name}",
          "arn:aws:s3:::${var.state_bucket_name}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:ap-south-1:${var.aws_account_id}:table/devops-assignment-tf-locks"
      }
    ]
  })
}
