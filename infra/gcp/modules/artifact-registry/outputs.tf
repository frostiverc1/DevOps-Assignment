output "repository_id" {
  value = google_artifact_registry_repository.docker.repository_id
}

output "registry_hostname" {
  description = "Hostname prefix for docker push (e.g. asia-south1-docker.pkg.dev)"
  value       = "${var.region}-docker.pkg.dev"
}

output "image_prefix" {
  description = "Full image prefix: <region>-docker.pkg.dev/<project>/<repo>"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
}
