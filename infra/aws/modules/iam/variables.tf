variable "project" {
  type    = string
  default = "devops-assignment"
}
variable "environment" {
  type = string
}
variable "github_repo" {
  description = "GitHub repo in org/repo format"
  type        = string
}
variable "aws_account_id" {
  type = string
}
variable "task_execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}
variable "state_bucket_name" {
  description = "S3 bucket name"
  type        = string
}
