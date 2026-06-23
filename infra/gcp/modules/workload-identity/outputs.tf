output "workload_identity_provider" {
  description = "Full provider resource name — set as GCP_WORKLOAD_IDENTITY_PROVIDER GitHub Actions secret"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "Service account email — set as GCP_SERVICE_ACCOUNT GitHub Actions secret"
  value       = google_service_account.github_actions.email
}
