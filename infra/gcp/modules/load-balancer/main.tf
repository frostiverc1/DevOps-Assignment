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

# ── Global Static IP ───────────────────────────────────────────────────────────

resource "google_compute_global_address" "lb_ip" {
  name    = "${local.name_prefix}-lb-ip"
  project = var.project_id
}

# ── Serverless NEG: Frontend ───────────────────────────────────────────────────
# Network Endpoint Groups allow the global LB to route to Cloud Run services

resource "google_compute_region_network_endpoint_group" "frontend" {
  name                  = "${local.name_prefix}-frontend-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  project               = var.project_id

  cloud_run {
    service = var.frontend_service_name
  }
}

# ── Serverless NEG: Backend ────────────────────────────────────────────────────

resource "google_compute_region_network_endpoint_group" "backend" {
  name                  = "${local.name_prefix}-backend-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  project               = var.project_id

  cloud_run {
    service = var.backend_service_name
  }
}

# ── Backend Services (LB concept, maps NEG to LB) ─────────────────────────────

resource "google_compute_backend_service" "frontend" {
  name                  = "${local.name_prefix}-frontend-bs"
  project               = var.project_id
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.frontend.id
  }
}

resource "google_compute_backend_service" "backend" {
  name                  = "${local.name_prefix}-backend-bs"
  project               = var.project_id
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.backend.id
  }
}

# ── URL Map: path-based routing ────────────────────────────────────────────────
# /api/* → backend Cloud Run service
# /* (default) → frontend Cloud Run service

resource "google_compute_url_map" "main" {
  name            = "${local.name_prefix}-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.frontend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.frontend.id

    path_rule {
      paths   = ["/api/*", "/api"]
      service = google_compute_backend_service.backend.id
    }
  }
}

# ── HTTP Proxy ─────────────────────────────────────────────────────────────────
# HTTP only (no domain for managed SSL certificate — documented gap).
# To add HTTPS: create google_compute_managed_ssl_certificate + google_compute_target_https_proxy

resource "google_compute_target_http_proxy" "main" {
  name    = "${local.name_prefix}-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.main.id
}

# ── Forwarding Rule (global) ───────────────────────────────────────────────────

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${local.name_prefix}-http-rule"
  project               = var.project_id
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.main.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
