terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { Project = "devops-assignment", Environment = "prod", ManagedBy = "terraform"
    }
  }
}

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
variable "frontend_image_tag" {
  type    = string
  default = "latest"
}
variable "backend_image_tag" {
  type    = string
  default = "latest"
}

module "vpc" {
  source      = "../../modules/vpc"
  project     = "devops-assignment"
  environment = "prod"
  aws_region  = var.aws_region
}

module "ecr" {
  source      = "../../modules/ecr"
  project     = "devops-assignment"
  environment = "prod"
}

module "alb" {
  source             = "../../modules/alb"
  project            = "devops-assignment"
  environment        = "prod"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  enable_access_logs = true # prod: access logs enabled
  aws_account_id     = var.aws_account_id
  aws_region         = var.aws_region
}

module "ecs" {
  source      = "../../modules/ecs"
  project     = "devops-assignment"
  environment = "prod"
  aws_region  = var.aws_region

  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  alb_security_group_id     = module.alb.alb_security_group_id
  frontend_target_group_arn = module.alb.frontend_target_group_arn
  backend_target_group_arn  = module.alb.backend_target_group_arn

  frontend_image = "${module.ecr.frontend_repo_url}:${var.frontend_image_tag}"
  backend_image  = "${module.ecr.backend_repo_url}:${var.backend_image_tag}"

  next_public_api_url = module.alb.alb_dns_name

  # prod sizing
  frontend_cpu    = 1024
  frontend_memory = 2048
  backend_cpu     = 1024
  backend_memory  = 2048
  task_count      = 2 # starting count

  # Autoscaling manages 2 to 6 tasks

  enable_autoscaling = true
  autoscaling_min    = 2
  autoscaling_max    = 6
  log_retention_days = 30
}

module "iam" {
  source                  = "../../modules/iam"
  project                 = "devops-assignment"
  environment             = "prod"
  github_repo             = var.github_repo
  aws_account_id          = var.aws_account_id
  task_execution_role_arn = module.ecs.task_execution_role_arn
  state_bucket_name       = var.state_bucket_name
}

module "secrets" {
  source      = "../../modules/secrets"
  project     = "devops-assignment"
  environment = "prod"
}

output "alb_url" { value = module.alb.alb_dns_name }
output "github_actions_role_arn" { value = module.iam.github_actions_role_arn }
output "frontend_ecr_url" { value = module.ecr.frontend_repo_url }
output "backend_ecr_url" { value = module.ecr.backend_repo_url }
