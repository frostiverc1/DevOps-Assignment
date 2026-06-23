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
variable "frontend_service_name" {
  type = string
}
variable "backend_service_name" {
  type = string
}
