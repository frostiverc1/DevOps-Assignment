output "frontend_repo_url" {
  description = "Full ECR URL for the frontend image"
  value       = aws_ecr_repository.app["frontend"].repository_url
}

output "backend_repo_url" {
  description = "Full ECR URL for the backend image"
  value       = aws_ecr_repository.app["backend"].repository_url
}

output "registry_id" {
  description = "ECR registry ID (AWS account ID)"
  value       = aws_ecr_repository.app["frontend"].registry_id
}
