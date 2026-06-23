terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "project" {
  type    = string
  default = "devops-assignment"
}
variable "environment" {
  type = string
}
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

resource "aws_secretsmanager_secret" "app_secret" {
  name                    = "${var.project}/${var.environment}/app-secret"
  description             = "Placeholder application secret"
  recovery_window_in_days = 7
  tags                    = { Environment = var.environment, Project = var.project }
}

resource "aws_secretsmanager_secret_version" "app_secret" {
  secret_id = aws_secretsmanager_secret.app_secret.id
  secret_string = jsonencode({
    APP_SECRET_KEY = "REPLACE_ME"
  })
}

output "app_secret_arn" {
  value = aws_secretsmanager_secret.app_secret.arn
}
