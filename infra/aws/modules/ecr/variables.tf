variable "project" {
  type    = string
  default = "devops-assignment"
}

variable "environment" {
  type = string
}

variable "image_tag_mutability" {
  description = "MUTABLE allows overwriting tags; IMMUTABLE does not"
  type        = string
  default     = "IMMUTABLE"
}
