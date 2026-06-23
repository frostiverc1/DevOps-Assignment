output "backend_service_url" {
  description = "Internal Cloud Run URL of the backend service"
  value       = google_cloud_run_v2_service.backend.uri
}

output "frontend_service_url" {
  description = "Cloud Run URL of the frontend service (before LB)"
  value       = google_cloud_run_v2_service.frontend.uri
}

output "backend_service_name" {
  value = google_cloud_run_v2_service.backend.name
}

output "frontend_service_name" {
  value = google_cloud_run_v2_service.frontend.name
}
