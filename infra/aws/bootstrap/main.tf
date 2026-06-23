# ─────────────────────────────────────────────────────────────────────────────
# AWS State Bootstrap
# Run ONCE with local state. After apply, all other Terraform configs use
# S3 + DynamoDB as their remote backend.
#
# Usage:
#   cd infra/aws/bootstrap
#   terraform init
#   terraform apply -var="aws_account_id=<YOUR_ACCOUNT_ID>"
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Intentionally local backend — this is the bootstrap layer.
  # Do NOT add a remote backend block here.
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "aws_account_id" {
  description = "AWS account ID (used in bucket name for global uniqueness)"
  type        = string
}

# ── S3 bucket for Terraform state ─────────────────────────────────────────────

resource "aws_s3_bucket" "tf_state" {
  bucket = "devops-assignment-tf-state-${var.aws_account_id}"

  # Prevent accidental deletion of state bucket
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "Terraform State"
    Project = "devops-assignment"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── DynamoDB table for state locking ──────────────────────────────────────────

resource "aws_dynamodb_table" "tf_locks" {
  name         = "devops-assignment-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "Terraform State Locks"
    Project = "devops-assignment"
  }
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "state_bucket_name" {
  description = "S3 bucket name — use as TF_STATE_BUCKET_AWS GitHub Actions secret"
  value       = aws_s3_bucket.tf_state.bucket
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.tf_locks.name
}
