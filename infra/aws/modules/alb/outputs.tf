output "alb_dns_name" {
  description = "ALB DNS name — use as NEXT_PUBLIC_API_URL for the frontend service"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "alb_security_group_id" {
  description = "ALB security group ID — passed to ECS module so tasks only accept ALB traffic"
  value       = aws_security_group.alb.id
}

output "frontend_target_group_arn" {
  value = aws_lb_target_group.frontend.arn
}

output "backend_target_group_arn" {
  value = aws_lb_target_group.backend.arn
}
