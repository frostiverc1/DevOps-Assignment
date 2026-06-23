variable "project" {
  type    = string
  default = "devops-assignment"
}
variable "environment" {
  type = string
}
variable "enable_access_logs" {
  description = "Enable ALB access logs to S3 (prod only)"
  type        = bool
}
variable "aws_account_id" {
  type    = string
  default = ""
}
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "vpc_id" {
  type = string
}
variable "public_subnet_ids" {
  type = list(string)
}
