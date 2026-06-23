#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# GCP Bootstrap Script
# Run ONCE manually before any `terraform apply` for GCP environments.
# This creates the 3 GCP projects, enables APIs, links billing, and creates
# the GCS buckets used as Terraform remote state.
#
# Prerequisites:
#   - gcloud CLI installed and authenticated: gcloud auth login
#   - You have a billing account: gcloud billing accounts list
#
# Usage:
#   chmod +x bootstrap.sh
#   BILLING_ACCOUNT_ID=XXXXXX-XXXXXX-XXXXXX \
#   SUFFIX=yourname \
#     ./bootstrap.sh
#
# After running, record the outputs and set them as GitHub Actions secrets.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

: "${BILLING_ACCOUNT_ID:?Set BILLING_ACCOUNT_ID to your GCP billing account}"
: "${SUFFIX:?Set SUFFIX to a short unique string (e.g. your initials) for globally unique bucket names}"

REGION="asia-south1"
ENVIRONMENTS=("dev" "staging" "prod")

for ENV in "${ENVIRONMENTS[@]}"; do
  PROJECT_ID="devops-assignment-${ENV}-${SUFFIX}"
  BUCKET_NAME="devops-tf-state-${ENV}-${SUFFIX}"

  echo ""
  echo "═══════════════════════════════════════════════════"
  echo " Setting up GCP environment: ${ENV}"
  echo " Project ID : ${PROJECT_ID}"
  echo " State Bucket: ${BUCKET_NAME}"
  echo "═══════════════════════════════════════════════════"

  # Create project (skip if already exists)
  if gcloud projects describe "${PROJECT_ID}" &>/dev/null; then
    echo "  ✔ Project ${PROJECT_ID} already exists, skipping create."
  else
    gcloud projects create "${PROJECT_ID}" \
      --name="DevOps Assignment ${ENV^}" \
      --labels="environment=${ENV},project=devops-assignment,managed-by=terraform"
    echo "  ✔ Project created."
  fi

  # Link billing account
  gcloud billing projects link "${PROJECT_ID}" \
    --billing-account="${BILLING_ACCOUNT_ID}"
  echo "  ✔ Billing linked."

  # Enable required APIs
  gcloud services enable \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    compute.googleapis.com \
    secretmanager.googleapis.com \
    iam.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iamcredentials.googleapis.com \
    --project="${PROJECT_ID}"
  echo "  ✔ APIs enabled."

  # Create GCS state bucket (skip if exists)
  if gcloud storage buckets describe "gs://${BUCKET_NAME}" --project="${PROJECT_ID}" &>/dev/null; then
    echo "  ✔ Bucket gs://${BUCKET_NAME} already exists, skipping."
  else
    gcloud storage buckets create "gs://${BUCKET_NAME}" \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --uniform-bucket-level-access
    echo "  ✔ State bucket created."
  fi

  # Enable versioning on state bucket
  gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning
  echo "  ✔ Versioning enabled on state bucket."

  echo ""
  echo "  Add this GitHub Actions secret:"
  echo "    GCP_PROJECT_ID_${ENV^^} = ${PROJECT_ID}"
  echo "    TF_STATE_BUCKET_GCP_${ENV^^} = ${BUCKET_NAME}"
done

echo ""
echo "═══════════════════════════════════════════════════"
echo " Bootstrap complete!"
echo " Next steps:"
echo "   1. Run: cd infra/gcp/environments/dev && terraform init -backend-config=backend.hcl"
echo "   2. Run: terraform apply -var-file=terraform.tfvars"
echo "   3. Record the workload_identity_provider output as GCP_WORKLOAD_IDENTITY_PROVIDER_DEV secret"
echo "   4. Record the service_account output as GCP_SERVICE_ACCOUNT secret"
echo "═══════════════════════════════════════════════════"
