# DevOps Assignment — Two-Cloud Infrastructure

FastAPI backend + Next.js 14 frontend deployed on **AWS ECS Fargate** and **GCP Cloud Run**, with fully automated CI/CD via GitHub Actions OIDC, Terraform-managed infrastructure across three environments (dev / staging / prod), and a bonus VPS deployment.

---

## Hosted URLs

| Cloud | Environment | URL |
|---|---|---|
| **AWS** (ECS Fargate) | dev | `http://<ALB-DNS>` — see Terraform output `alb_url` |
| **GCP** (Cloud Run) | dev | `http://<LB-IP>` — see Terraform output `lb_url` |
| **VPS** (EC2 + nginx) | bonus | `https://<EC2-IP>.nip.io` — see Terraform output `vps_https_url` |

> After running `terraform apply` for each environment, run `terraform output` to get the live URLs.

---

## Architecture Overview

```
GitHub Actions CI/CD (OIDC — no long-lived keys)
        │                          │
        ▼                          ▼
  AWS ap-south-1            GCP asia-south1
  ─────────────────         ─────────────────────
  ALB (HTTP, port 80)       Global HTTP LB (URL map)
  /api/* → backend          /api/* → backend Cloud Run
  /* → frontend             /* → frontend Cloud Run
        │                          │
  ECS Fargate               Cloud Run (scale-to-zero)
  private subnets           internal backend service
        │                          │
  ECR (images)              Artifact Registry (images)
  S3 + DynamoDB (state)     GCS bucket (state, versioned)
  3 state files per env     3 GCP projects (1 per env)
  IAM OIDC role             Workload Identity Federation
  Secrets Manager           Secret Manager
```

**Key contrast**: ECS Fargate = persistent containers (always-on, predictable latency). Cloud Run = scale-to-zero serverless (billed per request, cold start in dev/staging, `min_instance_count=1` in prod).

---

## Local Development

### Prerequisites

- Python 3.11+
- Node.js 20+
- Docker + Docker Compose

### Run with Docker Compose (recommended)

```bash
docker-compose up --build
```

- Frontend: [http://localhost:3000](http://localhost:3000)
- Backend: [http://localhost:8000](http://localhost:8000)
- Health check: [http://localhost:8000/api/health](http://localhost:8000/api/health)

### Run without Docker

**Backend:**
```bash
cd backend
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

**Frontend** (new terminal):
```bash
cd frontend
npm install
NEXT_PUBLIC_API_URL=http://localhost:8000 npm run dev
```

---

## Repository Structure

```
.
├── .github/workflows/
│   ├── aws-deploy.yml        # ECS rolling deploy (OIDC, commit SHA tag)
│   ├── gcp-deploy.yml        # Cloud Run deploy (Workload Identity)
│   ├── terraform-aws.yml     # Terraform plan/apply for AWS infra
│   └── terraform-gcp.yml     # Terraform plan/apply for GCP infra
├── backend/
│   ├── app/main.py           # FastAPI app (GET /api/health, GET /api/message)
│   ├── requirements.txt
│   └── Dockerfile            # Multi-stage, non-root, Python 3.11-slim
├── frontend/
│   ├── pages/index.js        # Next.js 14 SSR page
│   ├── package.json
│   └── Dockerfile            # Multi-stage, non-root, Node 20-alpine
├── infra/
│   ├── aws/
│   │   ├── bootstrap/        # S3 bucket + DynamoDB table (run once with local state)
│   │   ├── modules/
│   │   │   ├── vpc/          # VPC, subnets, IGW, NAT GW, route tables
│   │   │   ├── ecr/          # ECR repos + lifecycle policies
│   │   │   ├── ecs/          # Cluster, task defs, services, autoscaling
│   │   │   ├── alb/          # ALB, target groups, path-based routing
│   │   │   ├── iam/          # GitHub Actions OIDC role (no static keys)
│   │   │   └── secrets/      # AWS Secrets Manager placeholder
│   │   └── environments/
│   │       ├── dev/          # 256 CPU, 512 MB, 1 task, no autoscaling
│   │       ├── staging/      # 512 CPU, 1024 MB, 2 tasks
│   │       └── prod/         # 1024 CPU, 2048 MB, 2–6 tasks (autoscaling)
│   ├── gcp/
│   │   ├── bootstrap/        # bootstrap.sh: gcloud creates projects + GCS buckets
│   │   ├── modules/
│   │   │   ├── artifact-registry/   # Docker repo in asia-south1
│   │   │   ├── cloud-run/           # Backend (internal) + frontend (LB ingress)
│   │   │   ├── load-balancer/       # Global HTTP LB, NEGs, URL map
│   │   │   ├── workload-identity/   # WIF pool + OIDC provider (no JSON keys)
│   │   │   └── secret-manager/      # GCP Secret Manager placeholder
│   │   └── environments/
│   │       ├── dev/          # min_instances=0, 512Mi, separate GCP project
│   │       ├── staging/      # min_instances=0, 1Gi
│   │       └── prod/         # min_instances=1 (no cold start), 2Gi
│   └── vps/                  # EC2 t3.micro, nginx, PM2, Certbot (nip.io HTTPS)
└── docker-compose.yml        # Local integration test
```

---

## Infrastructure Setup

### AWS — First-time Setup

#### Step 1: Bootstrap state backend (run once)
```bash
cd infra/aws/bootstrap
terraform init
terraform apply -var="aws_account_id=<YOUR_ACCOUNT_ID>"
```

This creates:
- S3 bucket: `devops-assignment-tf-state-<account-id>` (versioning + SSE-S3)
- DynamoDB table: `devops-assignment-tf-locks`

#### Step 2: Fill in tfvars
Edit `infra/aws/environments/dev/terraform.tfvars`:
```hcl
aws_account_id    = "123456789012"
github_repo       = "yourorg/DevOps-Assignment"
state_bucket_name = "devops-assignment-tf-state-123456789012"
```

#### Step 3: Apply dev environment
```bash
cd infra/aws/environments/dev
terraform init -backend-config=backend.tf
terraform apply -var-file=terraform.tfvars
```

**State file locations** (separate blast radius per env):
- `aws/dev/terraform.tfstate`
- `aws/staging/terraform.tfstate`
- `aws/prod/terraform.tfstate`

### GCP — First-time Setup

#### Step 1: Bootstrap GCP projects
```bash
chmod +x infra/gcp/bootstrap/bootstrap.sh
BILLING_ACCOUNT_ID=XXXXXX-XXXXXX-XXXXXX \
SUFFIX=yourname \
  ./infra/gcp/bootstrap/bootstrap.sh
```

#### Step 2: Fill in tfvars
Edit `infra/gcp/environments/dev/terraform.tfvars`:
```hcl
project_id  = "devops-assignment-dev-yourname"
github_repo = "yourorg/DevOps-Assignment"
```

#### Step 3: Apply dev environment
```bash
cd infra/gcp/environments/dev
terraform init -backend-config=backend.tf
terraform apply -var-file=terraform.tfvars
```

Record the outputs → set as GitHub Actions secrets.

### VPS Bonus — EC2 + nginx + PM2 + Certbot

```bash
cd infra/vps
terraform init
terraform apply \
  -var="your_ip_cidr=$(curl -s ifconfig.me)/32" \
  -var="key_pair_name=your-key-pair-name"
```

HTTPS is provisioned automatically via Let's Encrypt + nip.io (no domain required).

---

## GitHub Actions Secrets Required

Set these in your fork's Settings → Secrets and variables → Actions:

| Secret | Description |
|---|---|
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |
| `AWS_ROLE_ARN_DEV` | Output of `terraform output github_actions_role_arn` (AWS) |
| `GH_REPO` | `yourorg/DevOps-Assignment` |
| `TF_STATE_BUCKET_AWS` | S3 bucket name from bootstrap output |
| `GCP_WORKLOAD_IDENTITY_PROVIDER_DEV` | Output of `terraform output workload_identity_provider` (GCP) |
| `GCP_SERVICE_ACCOUNT_DEV` | Output of `terraform output service_account_email` (GCP) |
| `GCP_PROJECT_ID_DEV` | GCP project ID for dev |
| `GCP_PROJECT_ID_STAGING` | GCP project ID for staging |
| `GCP_PROJECT_ID_PROD` | GCP project ID for prod |

> **No static AWS access keys or GCP JSON key files are used anywhere.**

---

## Deployment

### AWS — Rolling Deploy
```bash
# Automatic: push to main branch triggers aws-deploy.yml
# Manual:
gh workflow run aws-deploy.yml -f environment=staging
```

**Rollback:**
```bash
aws ecs update-service \
  --cluster devops-assignment-dev-cluster \
  --service devops-assignment-dev-backend \
  --task-definition devops-assignment-dev-backend:<PREV_REVISION> \
  --region ap-south-1
```

### GCP — Cloud Run Revision Deploy
```bash
# Automatic: push to main branch triggers gcp-deploy.yml
# Manual:
gh workflow run gcp-deploy.yml -f environment=dev
```

**Rollback (traffic shifting — no redeploy needed):**
```bash
gcloud run services update-traffic devops-assignment-dev-frontend \
  --to-revisions=PREVIOUS=100 \
  --region=asia-south1 \
  --project=devops-assignment-dev-yourname
```

---

## API Endpoints

| Endpoint | Response |
|---|---|
| `GET /api/health` | `{"status": "healthy", "message": "Backend is running successfully"}` |
| `GET /api/message` | `{"message": "You've successfully integrated the backend!"}` |

---

## Environment Differences

| | dev | staging | prod |
|---|---|---|---|
| **AWS CPU** | 256 | 512 | 1024 |
| **AWS Memory** | 512 MB | 1024 MB | 2048 MB |
| **AWS Tasks** | 1 | 2 | 2–6 (autoscaling) |
| **AWS Access Logs** | off | off | S3 |
| **GCP Memory** | 512Mi | 1Gi | 2Gi |
| **GCP Min Instances** | 0 (scale-to-zero) | 0 | 1 (no cold start) |
| **GCP Max Instances** | 3 | 5 | 20 |
| **GCP Projects** | separate | separate | separate |
| **Deletion Protection** | off | off | on |

---

## Design Document

📄 [Google Docs — Architecture & Design Decisions](https://docs.google.com/REPLACE_WITH_LINK)

Covers: cloud/region selection, architecture diagrams, compute decisions, networking/security, environment separation, scalability, deployment/rollback, state management, failure scenarios, future growth.

---

## Demo Video

🎬 [Loom Recording](https://loom.com/REPLACE_WITH_LINK)

8–12 min walkthrough: live app demo → architecture → IaC → CI/CD → tradeoffs → future growth.

---

## What We Did NOT Build (and why)

| Omission | Reason |
|---|---|
| Kubernetes | No justification for orchestrator overhead with 2 stateless services |
| HTTPS on ALB/GCP LB | No registered domain; VPS uses nip.io + Let's Encrypt |
| CDN | SSR reduces static cache benefit; adds scope without changing eval |
| WAF | No user auth/PII; cost vs. risk not warranted |
| Multi-region | Single region defensible for assignment scope |
| Blue/green | ECS rolling + Cloud Run traffic splitting already provide safe deploys |
| Separate AWS accounts per env | Single account + separate state keys is sufficient; documented as production gap |
| Cost alerting | Noted as production gap |
| Chaos engineering | Noted as production gap |
