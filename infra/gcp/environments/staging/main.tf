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

module "artifact_registry" {
  source      = "../../modules/artifact-registry"
  project_id  = var.project_id
  region      = var.region
  environment = "staging"
}

module "workload_identity" {
  source      = "../../modules/workload-identity"
  project_id  = var.project_id
  region      = var.region
  environment = "staging"
  github_repo = var.github_repo
}

module "cloud_run" {
  source               = "../../modules/cloud-run"
  project_id           = var.project_id
  region               = var.region
  environment          = "staging"
  backend_image        = "${module.artifact_registry.image_prefix}/backend:${var.backend_image_tag}"
  frontend_image       = "${module.artifact_registry.image_prefix}/frontend:${var.frontend_image_tag}"
  cloud_run_invoker_sa = module.workload_identity.service_account_email
  # staging: scale-to-zero still, more memory
  backend_min_instances  = 0
  backend_max_instances  = 5
  frontend_min_instances = 0
  frontend_max_instances = 5
  backend_cpu            = "1"
  backend_memory         = "1Gi"
  frontend_cpu           = "1"
  frontend_memory        = "1Gi"
}

module "load_balancer" {
  source                = "../../modules/load-balancer"
  project_id            = var.project_id
  region                = var.region
  environment           = "staging"
  frontend_service_name = module.cloud_run.frontend_service_name
  backend_service_name  = module.cloud_run.backend_service_name
}

module "secret_manager" {
  source             = "../../modules/secret-manager"
  project_id         = var.project_id
  environment        = "staging"
  cloud_run_sa_email = module.workload_identity.service_account_email
}

output "lb_url" { value = module.load_balancer.lb_url }
output "workload_identity_provider" { value = module.workload_identity.workload_identity_provider }
output "service_account_email" { value = module.workload_identity.service_account_email }
output "image_prefix" { value = module.artifact_registry.image_prefix }
