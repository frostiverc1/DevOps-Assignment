variable "project_id" {
  type = string
}
variable "region" {
  type    = string
  default = "asia-south1"
}
variable "environment" {
  type = string
}
variable "project" {
  type    = string
  default = "devops-assignment"
}
variable "backend_image" {
  type = string
}
variable "frontend_image" {
  type = string
}
variable "backend_cpu" {
  type    = string
  default = "1"
}
variable "backend_memory" {
  type    = string
  default = "512Mi"
}
variable "frontend_cpu" {
  type    = string
  default = "1"
}
variable "frontend_memory" {
  type    = string
  default = "512Mi"
}
variable "backend_min_instances" {
  type    = number
  default = 0
}
variable "backend_max_instances" {
  type    = number
  default = 3
}
variable "frontend_min_instances" {
  type    = number
  default = 0
}
variable "frontend_max_instances" {
  type    = number
  default = 3
}
variable "cloud_run_invoker_sa" {
  type = string
}
