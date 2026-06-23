variable "project" {
  type    = string
  default = "devops-assignment"
}
variable "environment" {
  type = string
}
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "vpc_id" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "alb_security_group_id" {
  type = string
}
variable "frontend_target_group_arn" {
  type = string
}
variable "backend_target_group_arn" {
  type = string
}
variable "frontend_image" {
  description = "Full ECR image URI for frontend"
  type        = string
}
variable "backend_image" {
  description = "Full ECR image URI for backend"
  type        = string
}
variable "frontend_cpu" {
  type    = number
  default = 256
}
variable "frontend_memory" {
  type    = number
  default = 512
}
variable "backend_cpu" {
  type    = number
  default = 256
}
variable "backend_memory" {
  type    = number
  default = 512
}
variable "task_count" {
  description = "Desired number of tasks"
  type        = number
}
variable "enable_autoscaling" {
  type    = bool
  default = false
}
variable "autoscaling_min" {
  type    = number
  default = 2
}
variable "autoscaling_max" {
  type    = number
  default = 6
}
variable "next_public_api_url" {
  description = "ALB DNS name"
  type        = string
}
variable "log_retention_days" {
  type    = number
  default = 7
}
