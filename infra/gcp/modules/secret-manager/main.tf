terraform {
  required_providers {
    google = { source = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  type = string
}
variable "project" {
  type    = string
  default = "devops-assignment"
}
variable "environment" {
  type = string
}
variable "cloud_run_sa_email" {
  type = string
}

resource "google_secret_manager_secret" "app_secret" {
  project   = var.project_id
  secret_id = "app-secret"

  replication {
    auto {}
  }

  labels = { environment = var.environment, project = var.project }
}

resource "google_secret_manager_secret_version" "app_secret" {
  secret = google_secret_manager_secret.app_secret.id
  # Placeholder — update via GCP Console or gcloud before deploying
  secret_data = "REPLACE_ME"
}

# Grant Cloud Run service account access to read secrets
resource "google_secret_manager_secret_iam_member" "cloud_run_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.app_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.cloud_run_sa_email}"
}

output "app_secret_id" {
  value = google_secret_manager_secret.app_secret.secret_id
}
