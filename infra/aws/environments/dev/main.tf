# ─────────────────────────────────────────────────────────────────────────────
# AWS Dev Environment
# Usage:
#   cd infra/aws/environments/dev
#   terraform init -backend-config=backend.tf
#   terraform apply -var-file=terraform.tfvars
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {} # Configured via backend.tf passed to -backend-config
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "devops-assignment"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

# ── Variables ──────────────────────────────────────────────────────────────────

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "aws_account_id" {
  type = string
}
variable "github_repo" {
  type = string
}
variable "state_bucket_name" {
  type = string
}

# Image tags — updated by CI/CD on every deploy
variable "frontend_image_tag" {
  type    = string
  default = "latest"
}
variable "backend_image_tag" {
  type    = string
  default = "latest"
}

# ── Module: VPC ────────────────────────────────────────────────────────────────

module "vpc" {
  source      = "../../modules/vpc"
  project     = "devops-assignment"
  environment = "dev"
  aws_region  = var.aws_region
}

# ── Module: ECR ────────────────────────────────────────────────────────────────

module "ecr" {
  source      = "../../modules/ecr"
  project     = "devops-assignment"
  environment = "dev"
}

# ── Module: ALB ────────────────────────────────────────────────────────────────

module "alb" {
  source             = "../../modules/alb"
  project            = "devops-assignment"
  environment        = "dev"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  enable_access_logs = false # dev: no access logs
  aws_account_id     = var.aws_account_id
}

# ── Module: ECS ────────────────────────────────────────────────────────────────

module "ecs" {
  source      = "../../modules/ecs"
  project     = "devops-assignment"
  environment = "dev"
  aws_region  = var.aws_region

  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  alb_security_group_id     = module.alb.alb_security_group_id
  frontend_target_group_arn = module.alb.frontend_target_group_arn
  backend_target_group_arn  = module.alb.backend_target_group_arn

  frontend_image = "${module.ecr.frontend_repo_url}:${var.frontend_image_tag}"
  backend_image  = "${module.ecr.backend_repo_url}:${var.backend_image_tag}"

  next_public_api_url = module.alb.alb_dns_name

  # dev sizing
  frontend_cpu    = 256
  frontend_memory = 512
  backend_cpu     = 256
  backend_memory  = 512
  task_count      = 1

  enable_autoscaling = false
  log_retention_days = 7
}

# ── Module: IAM (OIDC) ────────────────────────────────────────────────────────

module "iam" {
  source                  = "../../modules/iam"
  project                 = "devops-assignment"
  environment             = "dev"
  github_repo             = var.github_repo
  aws_account_id          = var.aws_account_id
  task_execution_role_arn = module.ecs.task_execution_role_arn
  state_bucket_name       = var.state_bucket_name
}

# ── Module: Secrets ────────────────────────────────────────────────────────────

module "secrets" {
  source      = "../../modules/secrets"
  project     = "devops-assignment"
  environment = "dev"
}

# ── Outputs ────────────────────────────────────────────────────────────────────

output "alb_url" {
  description = "Dev environment URL"
  value       = module.alb.alb_dns_name
}

output "github_actions_role_arn" {
  description = "Set as AWS_ROLE_ARN_DEV GitHub Actions secret"
  value       = module.iam.github_actions_role_arn
}

output "frontend_ecr_url" {
  value = module.ecr.frontend_repo_url
}

output "backend_ecr_url" {
  value = module.ecr.backend_repo_url
}
