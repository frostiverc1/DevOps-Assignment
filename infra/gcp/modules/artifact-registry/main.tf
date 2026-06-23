terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = "Docker images for ${var.project} ${var.environment}"
  format        = "DOCKER"

  labels = {
    environment = var.environment
    project     = var.project
    managed-by  = "terraform"
  }
}
