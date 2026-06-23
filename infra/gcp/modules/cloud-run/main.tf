terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Cloud Run Service: Backend ─────────────────────────────────────────────────
# Internal only — not accessible from the public internet directly.
# Frontend calls it via the internal Cloud Run service URL.
# This is a meaningful architectural difference from AWS (where the backend
# is behind the ALB and reachable only from the ALB security group).

resource "google_cloud_run_v2_service" "backend" {
  name     = "${local.name_prefix}-backend"
  location = var.region
  project  = var.project_id

  # Internal only: no direct public internet access
  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = var.cloud_run_invoker_sa

    scaling {
      min_instance_count = var.backend_min_instances
      max_instance_count = var.backend_max_instances
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello" # Placeholder image for initial apply

      ports {
        container_port = 8000
      }

      resources {
        limits = {
          cpu    = var.backend_cpu
          memory = var.backend_memory
        }
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      startup_probe {
        http_get {
          path = "/api/health"
          port = 8000
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/api/health"
          port = 8000
        }
        period_seconds    = 30
        failure_threshold = 3
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }

  labels = {
    environment = var.environment
    project     = var.project
    managed-by  = "terraform"
  }
}

# ── Cloud Run Service: Frontend ────────────────────────────────────────────────
# Accepts traffic from the Cloud Load Balancer and internal services.
# NEXT_PUBLIC_API_URL points to the backend's internal Cloud Run URL —
# frontend → backend communication stays within GCP, not through the LB.

resource "google_cloud_run_v2_service" "frontend" {
  name     = "${local.name_prefix}-frontend"
  location = var.region
  project  = var.project_id

  # Accept traffic from the Cloud Load Balancer (and internal)
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = var.cloud_run_invoker_sa

    scaling {
      min_instance_count = var.frontend_min_instances
      max_instance_count = var.frontend_max_instances
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello" # Placeholder image for initial apply

      ports {
        container_port = 3000
      }

      resources {
        limits = {
          cpu    = var.frontend_cpu
          memory = var.frontend_memory
        }
      }

      # Frontend calls backend via internal Cloud Run URL — not through the LB
      env {
        name  = "NEXT_PUBLIC_API_URL"
        value = google_cloud_run_v2_service.backend.uri
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      startup_probe {
        http_get {
          path = "/"
          port = 3000
        }
        initial_delay_seconds = 10
        period_seconds        = 5
        failure_threshold     = 3
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }

  labels = {
    environment = var.environment
    project     = var.project
    managed-by  = "terraform"
  }

  # Frontend depends on backend being deployed first (to get its URI)
  depends_on = [google_cloud_run_v2_service.backend]
}

# ── IAM: Allow Cloud Load Balancer to invoke the frontend service ─────────────
# Backend is internal-only, so no public IAM binding needed there.

resource "google_cloud_run_v2_service_iam_member" "frontend_lb_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers" # Required for public LB → Cloud Run
}
