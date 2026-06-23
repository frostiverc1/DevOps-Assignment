# ─────────────────────────────────────────────────────────────────────────────
# GCP Dev Environment
# Separate GCP project: devops-assignment-dev-<SUFFIX>
# State: GCS bucket devops-tf-state-dev-<SUFFIX>
#
# Key difference from AWS: separate GCP projects per env (not namespacing).
# AWS uses one account + separate state keys.
# GCP uses separate projects — stronger blast radius boundary.
#
# Usage:
#   cd infra/gcp/environments/dev
#   terraform init -backend-config=backend.hcl
#   terraform apply -var-file=terraform.tfvars
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type = string
}
variable "region" {
  type    = string
  default = "asia-south1"
}
variable "github_repo" {
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

# ── Artifact Registry ─────────────────────────────────────────────────────────

module "artifact_registry" {
  source      = "../../modules/artifact-registry"
  project_id  = var.project_id
  region      = var.region
  environment = "dev"
}

# ── Workload Identity (GitHub Actions OIDC) ───────────────────────────────────

module "workload_identity" {
  source      = "../../modules/workload-identity"
  project_id  = var.project_id
  region      = var.region
  environment = "dev"
  github_repo = var.github_repo
}

# ── Cloud Run Services ────────────────────────────────────────────────────────

module "cloud_run" {
  source      = "../../modules/cloud-run"
  project_id  = var.project_id
  region      = var.region
  environment = "dev"

  backend_image  = "${module.artifact_registry.image_prefix}/backend:${var.backend_image_tag}"
  frontend_image = "${module.artifact_registry.image_prefix}/frontend:${var.frontend_image_tag}"

  cloud_run_invoker_sa = module.workload_identity.service_account_email

  # dev: scale-to-zero (min=0)
  backend_min_instances  = 0
  backend_max_instances  = 3
  frontend_min_instances = 0
  frontend_max_instances = 3
  backend_cpu            = "1"
  backend_memory         = "512Mi"
  frontend_cpu           = "1"
  frontend_memory        = "512Mi"
}

# ── Load Balancer ─────────────────────────────────────────────────────────────

module "load_balancer" {
  source                = "../../modules/load-balancer"
  project_id            = var.project_id
  region                = var.region
  environment           = "dev"
  frontend_service_name = module.cloud_run.frontend_service_name
  backend_service_name  = module.cloud_run.backend_service_name
}

# ── Secret Manager ────────────────────────────────────────────────────────────

module "secret_manager" {
  source             = "../../modules/secret-manager"
  project_id         = var.project_id
  environment        = "dev"
  cloud_run_sa_email = module.workload_identity.service_account_email
}

# ── Outputs ────────────────────────────────────────────────────────────────────

output "lb_url" {
  description = "GCP dev environment URL"
  value       = module.load_balancer.lb_url
}

output "workload_identity_provider" {
  description = "Set as GCP_WORKLOAD_IDENTITY_PROVIDER secret"
  value       = module.workload_identity.workload_identity_provider
}

output "service_account_email" {
  description = "Set as GCP_SERVICE_ACCOUNT secret"
  value       = module.workload_identity.service_account_email
}

output "image_prefix" {
  description = "Docker image prefix for CI/CD"
  value       = module.artifact_registry.image_prefix
}
