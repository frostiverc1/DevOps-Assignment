output "cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "backend_service_name" {
  value = aws_ecs_service.backend.name
}

output "frontend_service_name" {
  value = aws_ecs_service.frontend.name
}

output "backend_task_definition_family" {
  value = aws_ecs_task_definition.backend.family
}

output "frontend_task_definition_family" {
  value = aws_ecs_task_definition.frontend.family
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role (needed for IAM PassRole permission)"
  value       = aws_iam_role.task_execution.arn
}

output "ecs_tasks_security_group_id" {
  value = aws_security_group.ecs_tasks.id
}
