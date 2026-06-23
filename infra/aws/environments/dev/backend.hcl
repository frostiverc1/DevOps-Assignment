# Partial backend config — passed to terraform init via:
#   terraform init -backend-config=backend.hcl
#
# This keeps the state key per-environment (separate blast radius).
# Do NOT use workspaces — each env has its own state file.

bucket         = "devops-assignment-tf-state-297245370584"
key            = "aws/dev/terraform.tfstate"
region         = "ap-south-1"
dynamodb_table = "devops-assignment-tf-locks"
encrypt        = true
